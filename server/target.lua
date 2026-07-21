local resourceName = GetCurrentResourceName()
local cacheFile = ConfigTarget.CacheFile or 'object_offsets.json'
local libraries = {}
local RSGCore

local function getCore()
    if RSGCore then return RSGCore end
    if GetResourceState('rsg-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['rsg-core']:GetCoreObject() end)
    if ok then RSGCore = core end
    return RSGCore
end

local function validModel(model)
    return type(model) == 'number' and model == model and math.abs(model) <= 2147483648
end

local function validGroup(groupName)
    return type(groupName) == 'string'
        and ConfigGroups
        and ConfigGroups.Scenario
        and ConfigGroups.Scenario[groupName] ~= nil
end

local function validScenario(groupName, scenarioName)
    if type(scenarioName) ~= 'string' or not validGroup(groupName) then return false end
    local group = ConfigGroups.Scenario[groupName]
    for _, entry in ipairs(group.Poses or {}) do
        if entry[1] == scenarioName then return true end
    end
    for _, category in pairs(group.Scenarios or {}) do
        for _, entry in ipairs(category) do
            if entry[1] == scenarioName then return true end
        end
    end
    return false
end

local function normaliseOffset(value)
    if type(value) ~= 'table' then return nil end
    local maxOffset = tonumber(ConfigTarget.MaxOffset) or 6.0
    local x, y, z, heading = tonumber(value.x), tonumber(value.y), tonumber(value.z), tonumber(value.heading)
    if not x or not y or not z or not heading then return nil end
    if x ~= x or y ~= y or z ~= z or heading ~= heading then return nil end
    if math.abs(x) > maxOffset or math.abs(y) > maxOffset or math.abs(z) > maxOffset then return nil end
    return { x = x, y = y, z = z, heading = heading % 360.0 }
end

local function newLibrary(model)
    return {
        item = model,
        offsets = {},
        poses = { show = {}, noshow = {} },
    }
end

local function getLibrary(model, create)
    local key = tostring(model)
    if create and not libraries[key] then libraries[key] = newLibrary(model) end
    return libraries[key]
end

local function sameOffset(a, b)
    local epsilon = 0.0001
    return math.abs(a.x - b.x) <= epsilon
        and math.abs(a.y - b.y) <= epsilon
        and math.abs(a.z - b.z) <= epsilon
        and math.abs(a.heading - b.heading) <= epsilon
end

local function offsetNumber(library, offset)
    for index, saved in ipairs(library.offsets) do
        if sameOffset(saved, offset) then return index end
    end
    library.offsets[#library.offsets + 1] = offset
    return #library.offsets
end

local function setPose(library, visibility, groupName, scenarioName, offsetIndex)
    local bucket = library.poses[visibility]
    bucket[groupName] = bucket[groupName] or {}
    bucket[groupName][scenarioName] = offsetIndex
end

local function findPose(library, groupName, scenarioName)
    if not library then return nil end
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        local group = library.poses[visibility][groupName]
        if group and group[scenarioName] then return visibility, group[scenarioName] end
    end
end

local function removePose(library, visibility, groupName, scenarioName)
    local bucket = library.poses[visibility]
    local group = bucket[groupName]
    if not group then return end
    group[scenarioName] = nil
    if next(group) == nil then bucket[groupName] = nil end
end

local function compactOffsets(library)
    local used = {}
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for _, poses in pairs(library.poses[visibility]) do
            for _, index in pairs(poses) do
                index = tonumber(index)
                if index and library.offsets[index] then used[index] = true end
            end
        end
    end

    local oldIndexes = {}
    for index in pairs(used) do oldIndexes[#oldIndexes + 1] = index end
    table.sort(oldIndexes)

    local remap, compacted = {}, {}
    for _, oldIndex in ipairs(oldIndexes) do
        compacted[#compacted + 1] = library.offsets[oldIndex]
        remap[oldIndex] = #compacted
    end
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for _, poses in pairs(library.poses[visibility]) do
            for scenarioName, oldIndex in pairs(poses) do
                poses[scenarioName] = remap[tonumber(oldIndex)]
            end
        end
    end
    library.offsets = compacted
end

local function cleanBucket(library, destination, source)
    for groupName, poses in pairs(type(source) == 'table' and source or {}) do
        if validGroup(groupName) and type(poses) == 'table' then
            for scenarioName, index in pairs(poses) do
                index = tonumber(index)
                if validScenario(groupName, scenarioName) and index and library.offsets[index] then
                    setPose(library, destination, groupName, scenarioName, index)
                end
            end
        end
    end
end

local function normaliseLibrary(value)
    if type(value) ~= 'table' or not validModel(value.item) or type(value.offsets) ~= 'table' then return nil end
    local library = newLibrary(value.item)
    for _, offset in ipairs(value.offsets) do
        local clean = normaliseOffset(offset)
        if not clean then return nil end
        library.offsets[#library.offsets + 1] = clean
    end
    local poses = type(value.poses) == 'table' and value.poses or {}
    cleanBucket(library, 'show', poses.show)
    cleanBucket(library, 'noshow', poses.noshow)
    compactOffsets(library)
    if next(library.poses.show) == nil and next(library.poses.noshow) == nil then return nil end
    return library
end

local function importOffsetRecord(value)
    if type(value) ~= 'table' or not validModel(value.item) then return false end
    local offset = normaliseOffset(value.offset)
    if not offset or type(value.poses) ~= 'table' then return false end
    local library = getLibrary(value.item, true)
    local index = offsetNumber(library, offset)
    for scenarioName, pose in pairs(value.poses) do
        local groupName = type(pose) == 'table' and pose.group or nil
        if validScenario(groupName, scenarioName) then
            setPose(library, pose.show == true and 'show' or 'noshow', groupName, scenarioName, index)
        end
    end
    return true
end

local function loadLibraries()
    local contents = LoadResourceFile(resourceName, cacheFile)
    if not contents or contents == '' then return end
    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then
        print(('[%s] Could not decode %s; starting with empty object pose libraries.'):format(resourceName, cacheFile))
        return
    end

    local migrated = false
    for _, value in ipairs(decoded) do
        local library = normaliseLibrary(value)
        if library then
            libraries[tostring(library.item)] = library
        elseif importOffsetRecord(value) then
            migrated = true -- Imports the previous offset-record test format.
        end
    end
    for _, library in pairs(libraries) do compactOffsets(library) end
    return migrated
end

local function serialisedLibraries()
    local result = {}
    for _, library in pairs(libraries) do
        if next(library.poses.show) ~= nil or next(library.poses.noshow) ~= nil then
            compactOffsets(library)
            result[#result + 1] = library
        end
    end
    table.sort(result, function(a, b) return a.item < b.item end)
    return result
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function encodeBucket(lines, bucket, indent, prefix)
    prefix = prefix or ''
    local groups = sortedKeys(bucket)
    if #groups == 0 then
        lines[#lines + 1] = indent .. prefix .. '{}'
        return
    end

    lines[#lines + 1] = indent .. prefix .. '{'
    for groupIndex, groupName in ipairs(groups) do
        local groupIndent = indent .. '  '
        lines[#lines + 1] = groupIndent .. json.encode(groupName) .. ': {'
        local scenarios = sortedKeys(bucket[groupName])
        for scenarioIndex, scenarioName in ipairs(scenarios) do
            local comma = scenarioIndex < #scenarios and ',' or ''
            lines[#lines + 1] = groupIndent .. '  ' .. json.encode(scenarioName) .. ': '
                .. json.encode(bucket[groupName][scenarioName]) .. comma
        end
        local comma = groupIndex < #groups and ',' or ''
        lines[#lines + 1] = groupIndent .. '}' .. comma
    end
    lines[#lines + 1] = indent .. '}'
end

local function encodeLibraries(values)
    local lines = { '[' }
    for libraryIndex, library in ipairs(values) do
        lines[#lines + 1] = '  {'
        lines[#lines + 1] = '    "item": ' .. json.encode(library.item) .. ','
        lines[#lines + 1] = '    "offsets": ['
        for offsetIndex, offset in ipairs(library.offsets) do
            local comma = offsetIndex < #library.offsets and ',' or ''
            lines[#lines + 1] = ('      { "x": %s, "y": %s, "z": %s, "heading": %s }%s'):format(
                json.encode(offset.x),
                json.encode(offset.y),
                json.encode(offset.z),
                json.encode(offset.heading),
                comma
            )
        end
        lines[#lines + 1] = '    ],'
        lines[#lines + 1] = '    "poses": {'
        encodeBucket(lines, library.poses.show, '      ', '"show": ')
        lines[#lines] = lines[#lines] .. ','
        encodeBucket(lines, library.poses.noshow, '      ', '"noshow": ')
        lines[#lines + 1] = '    }'
        local comma = libraryIndex < #values and ',' or ''
        lines[#lines + 1] = '  }' .. comma
    end
    lines[#lines + 1] = ']'
    return table.concat(lines, '\n')
end

local function saveLibraries()
    local encoded = encodeLibraries(serialisedLibraries())
    if not SaveResourceFile(resourceName, cacheFile, encoded, -1) then
        print(('[%s] Failed to save object pose libraries to %s.'):format(resourceName, cacheFile))
        return false
    end
    return true
end

local function hasJobDeletePermission(source)
    local core = getCore()
    local player = core and core.Functions.GetPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if type(job) ~= 'table' or job.onduty ~= true then return false end
    for _, jobName in ipairs(ConfigTarget.AdminJobs or {}) do
        if job.name == jobName then return true end
    end
    return false
end

local function hasServerDeletePermission(source)
    local ace = ConfigTarget.ServerAdminAce
    if type(ace) == 'string' and ace ~= '' and IsPlayerAceAllowed(source, ace) then return true end
    local core = getCore()
    if not core or type(core.Functions.HasPermission) ~= 'function' then return false end
    for _, permission in ipairs(ConfigTarget.ServerAdminPermissions or { 'admin', 'god' }) do
        local ok, allowed = pcall(core.Functions.HasPermission, source, permission)
        if ok and allowed then return true end
    end
    return false
end

local function canManage(source)
    if ConfigTarget.DeletePermissionMode == 'server' then return hasServerDeletePermission(source) end
    return hasJobDeletePermission(source)
end

if loadLibraries() then saveLibraries() end

lib.callback.register('nt_actions:server:getObjectLibrary', function(source, model)
    if not validModel(model) then return { library = nil, canDelete = false } end
    return { library = getLibrary(model, false), canDelete = canManage(source) }
end)

lib.callback.register('nt_actions:server:saveObjectPose', function(source, model, groupName, scenarioName, value)
    if not validModel(model) or not validScenario(groupName, scenarioName) then return false end
    local cleanOffset = normaliseOffset(value)
    if not cleanOffset then return false end

    local library = getLibrary(model, true)
    local visibility = findPose(library, groupName, scenarioName)
    if visibility == 'noshow' then return false end -- Hidden poses require admin Undo.
    if visibility and ConfigTarget.AllowPlayerModify == false then return false end
    if not visibility and ConfigTarget.AllowPlayerBuild == false then return false end

    if visibility then removePose(library, visibility, groupName, scenarioName) end
    setPose(library, 'show', groupName, scenarioName, offsetNumber(library, cleanOffset))
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

lib.callback.register('nt_actions:server:hideObjectPose', function(source, model, groupName, scenarioName)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    local visibility, index = findPose(library, groupName, scenarioName)
    if visibility ~= 'show' then return false end
    removePose(library, 'show', groupName, scenarioName)
    setPose(library, 'noshow', groupName, scenarioName, index)
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

lib.callback.register('nt_actions:server:restoreObjectPose', function(source, model, groupName, scenarioName)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    local visibility, index = findPose(library, groupName, scenarioName)
    if visibility ~= 'noshow' then return false end
    removePose(library, 'noshow', groupName, scenarioName)
    setPose(library, 'show', groupName, scenarioName, index)
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)
