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
    return type(groupName) == 'string' and ConfigGroups and ConfigGroups.Scenario
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
    return { item = model, offsets = {}, poses = { show = {}, noshow = {} } }
end

local function getLibrary(model, create)
    local key = tostring(model)
    if create and not libraries[key] then libraries[key] = newLibrary(model) end
    return libraries[key]
end

local function sameOffset(a, b)
    local epsilon = 0.0001
    return math.abs(a.x - b.x) <= epsilon and math.abs(a.y - b.y) <= epsilon
        and math.abs(a.z - b.z) <= epsilon and math.abs(a.heading - b.heading) <= epsilon
end

local function existingOffsetNumber(library, offset)
    for index, saved in ipairs(library.offsets) do
        if sameOffset(saved, offset) then return index end
    end
end

local function offsetNumber(library, offset)
    local existing = existingOffsetNumber(library, offset)
    if existing then return existing end
    library.offsets[#library.offsets + 1] = offset
    return #library.offsets
end

local function addRecord(library, visibility, groupName, scenarioName, poseNumber, offsetIndex)
    local bucket = library.poses[visibility]
    bucket[groupName] = bucket[groupName] or {}
    local record = { scenario = scenarioName }
    if poseNumber ~= nil then record.number = tonumber(poseNumber) end
    if offsetIndex ~= nil then record.offset = tonumber(offsetIndex) end
    bucket[groupName][#bucket[groupName] + 1] = record
    return bucket[groupName][#bucket[groupName]]
end

local function findRecord(library, visibility, groupName, scenarioName, poseNumber)
    if not library then return nil end
    local expected = tonumber(poseNumber)
    local group = library.poses[visibility] and library.poses[visibility][groupName]
    for index, record in ipairs(group or {}) do
        if record.scenario == scenarioName and (poseNumber == nil or tonumber(record.number) == expected) then
            return record, index
        end
    end
end

local function removeRecord(library, visibility, groupName, index)
    local bucket = library.poses[visibility]
    local group = bucket[groupName]
    if not group or not group[index] then return nil end
    local record = table.remove(group, index)
    if #group == 0 then bucket[groupName] = nil end
    return record
end

local function scenarioRecords(library, groupName, scenarioName)
    local records = {}
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for _, record in ipairs(library.poses[visibility][groupName] or {}) do
            if record.scenario == scenarioName then records[#records + 1] = record end
        end
    end
    table.sort(records, function(a, b)
        local an, bn = tonumber(a.number), tonumber(b.number)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return false
    end)
    return records
end

local function normalisePoseNumbers(library, groupName, scenarioName)
    local records = scenarioRecords(library, groupName, scenarioName)
    if #records == 1 then
        records[1].number = nil
    elseif #records > 1 then
        for index, record in ipairs(records) do record.number = index end
    end
end

local function removeOffset(library, offsetIndex)
    offsetIndex = tonumber(offsetIndex)
    if not offsetIndex or not library.offsets[offsetIndex] then return false end
    table.remove(library.offsets, offsetIndex)
    return true
end

local function cleanBucket(library, destination, source, preserveAssociations)
    local migrated = false
    for groupName, poses in pairs(type(source) == 'table' and source or {}) do
        if validGroup(groupName) and type(poses) == 'table' then
            if #poses > 0 then
                for _, value in ipairs(poses) do
                    local scenarioName = type(value) == 'table' and (value.scenario or value[1]) or nil
                    local poseNumber = type(value) == 'table' and (value.number or value[2]) or nil
                    local offsetIndex = type(value) == 'table' and tonumber(value.offset or value[3]) or nil
                    if validScenario(groupName, scenarioName) then
                        if preserveAssociations then
                            if offsetIndex and library.offsets[offsetIndex] then
                                addRecord(library, destination, groupName, scenarioName, poseNumber, offsetIndex)
                            elseif offsetIndex == nil then
                                for index in ipairs(library.offsets) do
                                    addRecord(library, destination, groupName, scenarioName, nil, index)
                                end
                            end
                        elseif not findRecord(library, destination, groupName, scenarioName) then
                            addRecord(library, destination, groupName, scenarioName)
                        else
                            migrated = true
                        end
                        if poseNumber ~= nil or offsetIndex ~= nil then migrated = true end
                    end
                end
            else
                migrated = true
                for scenarioName, offsetIndex in pairs(poses) do
                    offsetIndex = tonumber(offsetIndex)
                    if validScenario(groupName, scenarioName) then
                        if preserveAssociations and offsetIndex and library.offsets[offsetIndex] then
                            addRecord(library, destination, groupName, scenarioName, nil, offsetIndex)
                        elseif not preserveAssociations and not findRecord(library, destination, groupName, scenarioName) then
                            addRecord(library, destination, groupName, scenarioName)
                        end
                    end
                end
            end
        end
    end
    return migrated
end

local function normaliseLibrary(value, preserveAssociations)
    if type(value) ~= 'table' or not validModel(value.item) or type(value.offsets) ~= 'table' then return nil end
    local library = newLibrary(value.item)
    for _, offset in ipairs(value.offsets) do
        local clean = normaliseOffset(offset)
        if not clean then return nil end
        library.offsets[#library.offsets + 1] = clean
    end
    local poses = type(value.poses) == 'table' and value.poses or {}
    local migrated = cleanBucket(library, 'show', poses.show, preserveAssociations)
    migrated = cleanBucket(library, 'noshow', poses.noshow, preserveAssociations) or migrated
    if preserveAssociations then
        local normalised = {}
        for _, visibility in ipairs({ 'show', 'noshow' }) do
            for groupName, records in pairs(library.poses[visibility]) do
                normalised[groupName] = normalised[groupName] or {}
                for _, record in ipairs(records) do
                    if not normalised[groupName][record.scenario] then
                        normalisePoseNumbers(library, groupName, record.scenario)
                        normalised[groupName][record.scenario] = true
                    end
                end
            end
        end
    end
    if #library.offsets == 0 and next(library.poses.show) == nil and next(library.poses.noshow) == nil then return nil end
    return library, migrated
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
        local library, changed = normaliseLibrary(value)
        if library then libraries[tostring(library.item)] = library end
        migrated = changed or migrated
    end
    return migrated
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function encodeBucket(lines, bucket, indent, prefix)
    local groups = sortedKeys(bucket)
    if #groups == 0 then lines[#lines + 1] = indent .. prefix .. '{}' return end
    lines[#lines + 1] = indent .. prefix .. '{'
    for groupIndex, groupName in ipairs(groups) do
        local groupIndent = indent .. '  '
        lines[#lines + 1] = groupIndent .. json.encode(groupName) .. ': ['
        for recordIndex, record in ipairs(bucket[groupName]) do
            local comma = recordIndex < #bucket[groupName] and ',' or ''
            local encoded = '[' .. json.encode(record.scenario)
            if record.offset ~= nil then
                encoded = encoded .. ', ' .. (record.number and json.encode(record.number) or 'null')
                    .. ', ' .. json.encode(record.offset)
            end
            lines[#lines + 1] = groupIndent .. '  ' .. encoded .. ']' .. comma
        end
        local comma = groupIndex < #groups and ',' or ''
        lines[#lines + 1] = groupIndent .. ']' .. comma
    end
    lines[#lines + 1] = indent .. '}'
end

local function serialisedLibraries()
    local result = {}
    for _, library in pairs(libraries) do
        if #library.offsets > 0 or next(library.poses.show) ~= nil or next(library.poses.noshow) ~= nil then
            result[#result + 1] = library
        end
    end
    table.sort(result, function(a, b) return a.item < b.item end)
    return result
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
                json.encode(offset.x), json.encode(offset.y), json.encode(offset.z), json.encode(offset.heading), comma)
        end
        lines[#lines + 1] = '    ],'
        lines[#lines + 1] = '    "poses": {'
        encodeBucket(lines, library.poses.show, '      ', '"show": ')
        lines[#lines] = lines[#lines] .. ','
        encodeBucket(lines, library.poses.noshow, '      ', '"noshow": ')
        lines[#lines + 1] = '    }'
        lines[#lines + 1] = '  }' .. (libraryIndex < #values and ',' or '')
    end
    lines[#lines + 1] = ']'
    return table.concat(lines, '\n')
end

local function saveLibraries()
    if not SaveResourceFile(resourceName, cacheFile, encodeLibraries(serialisedLibraries()), -1) then
        print(('[%s] Failed to save object pose libraries to %s.'):format(resourceName, cacheFile))
        return false
    end
    return true
end

local function hasConfiguredJob(source, configuredJobs)
    local core = getCore()
    local player = core and core.Functions.GetPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if type(job) ~= 'table' then return false end
    for _, jobName in ipairs(configuredJobs or {}) do
        if job.name == jobName then return true end
    end
    return false
end

local function canManage(source)
    return hasConfiguredJob(source, ConfigTarget.AdminJobs)
end

if loadLibraries() then saveLibraries() end

lib.callback.register('nt_actions:server:getObjectLibrary', function(source, model)
    if not validModel(model) then
        return { library = nil, canDelete = false }
    end
    return {
        library = getLibrary(model, false),
        canDelete = canManage(source),
    }
end)

lib.callback.register('nt_actions:server:saveObjectPose', function(source, model, groupName, scenarioName, value, mode, coordNumber, separate)
    if not validModel(model) or not validScenario(groupName, scenarioName) then return false end
    local cleanOffset = normaliseOffset(value)
    if not cleanOffset then return false end
    mode = mode == 'modify' and 'modify' or 'add'
    coordNumber = tonumber(coordNumber)
    if coordNumber == 0 then coordNumber = nil end
    separate = separate == true

    if not canManage(source) then return false end
    local library = getLibrary(model, true)

    local shown = findRecord(library, 'show', groupName, scenarioName)
    local hidden = findRecord(library, 'noshow', groupName, scenarioName)
    if mode == 'modify' and (not shown or not coordNumber or not library.offsets[coordNumber]) then return false end
    if mode == 'add' and hidden then return false end

    local selectedOffset = existingOffsetNumber(library, cleanOffset)
    if mode == 'modify' and coordNumber and not separate then
        if selectedOffset and selectedOffset ~= coordNumber then
            removeOffset(library, coordNumber)
            if selectedOffset > coordNumber then selectedOffset = selectedOffset - 1 end
        else
            library.offsets[coordNumber] = cleanOffset
            selectedOffset = coordNumber
        end
    else
        selectedOffset = selectedOffset or offsetNumber(library, cleanOffset)
    end
    if not shown then addRecord(library, 'show', groupName, scenarioName) end
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return { coordNumber = selectedOffset }
end)

lib.callback.register('nt_actions:server:bulkAddObjectPoses', function(source, model, selections)
    if not validModel(model) or not canManage(source) or type(selections) ~= 'table'
    then
        return false
    end
    local library = getLibrary(model, true)
    local pending, requested = {}, {}
    local skipped = 0

    for index, selection in ipairs(selections) do
        if index > 512 then break end
        local groupName = type(selection) == 'table' and selection.group or nil
        local scenarioName = type(selection) == 'table' and selection.scenario or nil
        local key = tostring(groupName) .. '\0' .. tostring(scenarioName)
        if requested[key] then
            skipped = skipped + 1
        elseif validScenario(groupName, scenarioName) then
            requested[key] = true
            local shown = findRecord(library, 'show', groupName, scenarioName)
            local hidden = findRecord(library, 'noshow', groupName, scenarioName)
            if shown or hidden then
                skipped = skipped + 1
            else
                pending[#pending + 1] = { group = groupName, scenario = scenarioName }
            end
        else
            skipped = skipped + 1
        end
    end

    if #pending == 0 then return { added = 0, skipped = skipped } end
    if #library.offsets == 0 then
        local defaultPoint = normaliseOffset(ConfigTarget.DefaultOffset or {})
        if not defaultPoint then return false end
        offsetNumber(library, defaultPoint)
    end
    for _, selection in ipairs(pending) do
        addRecord(library, 'show', selection.group, selection.scenario)
    end
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return { added = #pending, skipped = skipped }
end)

lib.callback.register('nt_actions:server:hideObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    local _, index = findRecord(library, 'show', groupName, scenarioName)
    if not index then return false end
    local record = removeRecord(library, 'show', groupName, index)
    addRecord(library, 'noshow', groupName, record.scenario)
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

lib.callback.register('nt_actions:server:restoreObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    local _, index = findRecord(library, 'noshow', groupName, scenarioName)
    if not index then return false end
    local record = removeRecord(library, 'noshow', groupName, index)
    addRecord(library, 'show', groupName, record.scenario)
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

lib.callback.register('nt_actions:server:deleteHiddenObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    local _, index = findRecord(library, 'noshow', groupName, scenarioName)
    if not index then return false end
    removeRecord(library, 'noshow', groupName, index)
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

lib.callback.register('nt_actions:server:deleteObjectPoint', function(source, model, offsetIndex)
    if not validModel(model) or not canManage(source) then return false end
    local library = getLibrary(model, false)
    if not library then return false end
    local hasPoses = next(library.poses.show or {}) ~= nil or next(library.poses.noshow or {}) ~= nil
    if hasPoses and #library.offsets <= 1 then return false end
    if not removeOffset(library, tonumber(offsetIndex)) then return false end
    if not saveLibraries() then return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)

-- Narrow server API used by the isolated batch-review feature.
NtActionsLibrary = NtActionsLibrary or {}
NtActionsLibrary.canManage = canManage
NtActionsLibrary.hasConfiguredJob = hasConfiguredJob
NtActionsLibrary.validModel = validModel
NtActionsLibrary.validGroup = validGroup
NtActionsLibrary.validScenario = validScenario
NtActionsLibrary.normaliseOffset = normaliseOffset
NtActionsLibrary.normaliseLibrary = normaliseLibrary
NtActionsLibrary.encodeLibraries = encodeLibraries
NtActionsLibrary.sameOffset = sameOffset

function NtActionsLibrary.hasExactPose(model, groupName, scenarioName, offset)
    local library = getLibrary(model, false)
    if not library then return false end
    if #scenarioRecords(library, groupName, scenarioName) == 0 then return false end
    return existingOffsetNumber(library, offset) ~= nil
end

function NtActionsLibrary.getReviewState(model)
    local library = getLibrary(model, false)
    local state = { offsets = {}, poses = {} }
    if not library then return state end
    for _, offset in ipairs(library.offsets or {}) do
        state.offsets[#state.offsets + 1] = normaliseOffset(offset)
    end
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for groupName, records in pairs(library.poses[visibility] or {}) do
            for _, record in ipairs(records) do
                state.poses[groupName .. '\0' .. record.scenario] = visibility
            end
        end
    end
    return state
end

function NtActionsLibrary.mergeReviewedPose(model, groupName, scenarioName)
    if not validModel(model) or not validScenario(groupName, scenarioName) then return false end
    local library = getLibrary(model, true)
    if #scenarioRecords(library, groupName, scenarioName) > 0 then return false end
    addRecord(library, 'show', groupName, scenarioName)
    return true
end

function NtActionsLibrary.mergeReviewedPoint(model, offset)
    if not validModel(model) then return false end
    local cleanOffset = normaliseOffset(offset)
    if not cleanOffset then return false end
    local library = getLibrary(model, true)
    if existingOffsetNumber(library, cleanOffset) then return false end
    offsetNumber(library, cleanOffset)
    return true
end

function NtActionsLibrary.save()
    return saveLibraries()
end
