local resourceName = GetCurrentResourceName()
local cacheFile = ConfigTarget.CacheFile or 'object_offsets.json'
local poseOffsetFile = ConfigTarget.PoseOffsetFile or 'pose_offset.json'
local libraries = {}
local presets = {}
local poseOffsets = {}
local DEFAULT_POINT_GROUP = 'Group 1'
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
    return {
        item = model,
        offsets = {},
        pointGroups = {},
        pointGroupNames = {},
        posePointGroups = {},
        poses = { show = {}, noshow = {} },
    }
end

local function getLibrary(model)
    local saved = libraries[tostring(model)]
    return saved and saved.preset and presets[saved.preset] or nil
end

local function presetForModel(model)
    local saved = libraries[tostring(model)]
    return saved and saved.preset or nil
end

local function objectOffsetForModel(model)
    local saved = libraries[tostring(model)]
    return saved and saved.offset or nil
end

local function cleanPresetName(value)
    local name = type(value) == 'string' and value:match('^%s*(.-)%s*$') or nil
    if not name or name == '' or #name > 64 then return nil end
    return name
end

local function ensureItemPreset(model, requestedName)
    local library = getLibrary(model)
    if library then return library end
    local name = cleanPresetName(requestedName)
    if not name then return nil end
    if not presets[name] then
        presets[name] = newLibrary(0)
        presets[name].pointGroupNames[DEFAULT_POINT_GROUP] = true
    end
    libraries[tostring(model)] = { item = model, preset = name }
    return presets[name]
end

local function broadcastLibraryUpdate(model)
    local presetName = presetForModel(model)
    if not presetName then
        TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
        return
    end
    for key, saved in pairs(libraries) do
        if saved.preset == presetName then
            TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, tonumber(key))
        end
    end
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

local function offsetNumber(library, offset, pointGroup)
    local existing = existingOffsetNumber(library, offset)
    if existing then
        library.pointGroups[existing] = library.pointGroups[existing] or pointGroup or DEFAULT_POINT_GROUP
        return existing
    end
    library.offsets[#library.offsets + 1] = offset
    library.pointGroups[#library.offsets] = pointGroup or DEFAULT_POINT_GROUP
    return #library.offsets
end

local function addRecord(library, visibility, groupName, scenarioName, poseNumber, offsetIndex, pointGroup)
    local bucket = library.poses[visibility]
    bucket[groupName] = bucket[groupName] or {}
    local record = { scenario = scenarioName }
    if poseNumber ~= nil then record.number = tonumber(poseNumber) end
    if offsetIndex ~= nil then record.offset = tonumber(offsetIndex) end
    bucket[groupName][#bucket[groupName] + 1] = record
    library.posePointGroups[scenarioName] = pointGroup or library.posePointGroups[scenarioName] or DEFAULT_POINT_GROUP
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
    table.remove(library.pointGroups, offsetIndex)
    return true
end

local function cleanBucket(library, destination, source, preserveAssociations, importPointGroup)
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
                                addRecord(library, destination, groupName, scenarioName, poseNumber, offsetIndex,
                                    importPointGroup or library.pointGroups[offsetIndex])
                            elseif offsetIndex == nil then
                                for index in ipairs(library.offsets) do
                                    if not importPointGroup or library.pointGroups[index] == importPointGroup then
                                        addRecord(library, destination, groupName, scenarioName, nil, index,
                                            importPointGroup or library.pointGroups[index])
                                    end
                                end
                            end
                        elseif not findRecord(library, destination, groupName, scenarioName) then
                            addRecord(library, destination, groupName, scenarioName, nil, nil, importPointGroup)
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
                            addRecord(library, destination, groupName, scenarioName, nil, offsetIndex,
                                importPointGroup or library.pointGroups[offsetIndex])
                        elseif not preserveAssociations and not findRecord(library, destination, groupName, scenarioName) then
                            addRecord(library, destination, groupName, scenarioName, nil, nil, importPointGroup)
                        end
                    end
                end
            end
        end
    end
    return migrated
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function importOffsets(library, source)
    if #source > 0 then
        for _, offset in ipairs(source) do
            local clean = normaliseOffset(offset)
            if not clean then return false end
            offsetNumber(library, clean, DEFAULT_POINT_GROUP)
        end
        library.pointGroupNames[DEFAULT_POINT_GROUP] = true
        return true, true
    end
    for _, pointGroup in ipairs(sortedKeys(source)) do
        local offsets = source[pointGroup]
        if type(pointGroup) == 'string' and pointGroup ~= '' and type(offsets) == 'table' then
            library.pointGroupNames[pointGroup] = true
            for _, offset in ipairs(offsets) do
                local clean = normaliseOffset(offset)
                if not clean then return false end
                offsetNumber(library, clean, pointGroup)
            end
        end
    end
    return true, false
end

local function assignImportedPoses(library, pointGroup)
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for _, records in pairs(library.poses[visibility]) do
            for _, record in ipairs(records) do
                library.posePointGroups[record.scenario] = library.posePointGroups[record.scenario] or pointGroup
            end
        end
    end
end

local function normaliseLibrary(value, preserveAssociations)
    if type(value) ~= 'table' or not validModel(value.item) or type(value.offsets) ~= 'table' then return nil end
    local library = newLibrary(value.item)
    local offsetsOk, legacyOffsets = importOffsets(library, value.offsets)
    if not offsetsOk then return nil end
    local poses = type(value.poses) == 'table' and value.poses or {}
    local migrated = legacyOffsets
    if poses.show ~= nil or poses.noshow ~= nil then
        migrated = true
        cleanBucket(library, 'show', poses.show, preserveAssociations)
        cleanBucket(library, 'noshow', poses.noshow, preserveAssociations)
        assignImportedPoses(library, DEFAULT_POINT_GROUP)
    else
        for pointGroup, groupedPoses in pairs(poses) do
            if type(pointGroup) == 'string' and pointGroup ~= '' and type(groupedPoses) == 'table' then
                library.pointGroupNames[pointGroup] = true
                local before = {}
                for _, visibility in ipairs({ 'show', 'noshow' }) do
                    for _, records in pairs(library.poses[visibility]) do
                        for _, record in ipairs(records) do before[record.scenario] = true end
                    end
                end
                cleanBucket(library, 'show', groupedPoses.show, preserveAssociations, pointGroup)
                cleanBucket(library, 'noshow', groupedPoses.noshow, preserveAssociations, pointGroup)
                for _, visibility in ipairs({ 'show', 'noshow' }) do
                    for _, records in pairs(library.poses[visibility]) do
                        for _, record in ipairs(records) do
                            if not before[record.scenario] then library.posePointGroups[record.scenario] = pointGroup end
                        end
                    end
                end
            end
        end
    end
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
local function getEditableLibrary(model)
    return getLibrary(model)
end
local function importPresetValues(values)
    for _, value in ipairs(type(values) == 'table' and values or {}) do
        if type(value) == 'table' and type(value.name) == 'string' and value.name ~= '' then
            local candidate = {}
            for key, entry in pairs(value) do candidate[key] = entry end
            candidate.item = 0
            local library = normaliseLibrary(candidate)
            if library then presets[value.name] = library end
        end
    end
end

local function uniqueMigratedPresetName(model)
    local base, suffix = ('Item %s'):format(model), 1
    local name = base
    while presets[name] do
        suffix = suffix + 1
        name = ('%s %d'):format(base, suffix)
    end
    return name
end

local function importObjectValues(values)
    local migrated = false
    for _, value in ipairs(type(values) == 'table' and values or {}) do
        if type(value) == 'table' and validModel(value.item) and type(value.preset) == 'string' and value.preset ~= '' then
            libraries[tostring(value.item)] = { item = value.item, preset = value.preset }
        else
            local library, changed = normaliseLibrary(value)
            if library then
                local name = uniqueMigratedPresetName(library.item)
                local model = library.item
                library.item = 0
                presets[name] = library
                libraries[tostring(model)] = { item = model, preset = name }
                migrated = true
            end
            migrated = changed or migrated
        end
    end
    return migrated
end

local function loadLibraries()
    local contents = LoadResourceFile(resourceName, cacheFile)
    if not contents or contents == '' then return end
    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then
        print(('[%s] Could not decode %s; starting with empty presets and item assignments.'):format(resourceName, cacheFile))
        return
    end
    importPresetValues(decoded.presets)
    local migrated = false
    if type(decoded.items) == 'table' then
        for modelKey, assignment in pairs(decoded.items) do
            local model = tonumber(modelKey)
            local presetName = type(assignment) == 'string' and assignment
                or type(assignment) == 'table' and (assignment.preset or assignment[1])
            local offsetValue = type(assignment) == 'table' and (assignment.offset or assignment[2]) or nil
            local offset = normaliseOffset(offsetValue)
            if validModel(model) and type(presetName) == 'string' and presetName ~= '' then
                libraries[tostring(model)] = { item = model, preset = presetName, offset = offset }
            end
        end
    elseif type(decoded.objects) == 'table' then
        migrated = importObjectValues(decoded.objects) or true
    else
        migrated = importObjectValues(decoded) or true
    end
    return migrated
end
local function poseOrder(scenarioName)
    return tonumber(masterOrder and masterOrder[scenarioName]) or math.huge
end

local function orderedPoseGroups(bucket)
    local groups = sortedKeys(bucket)
    table.sort(groups, function(a, b)
        local ao = tonumber(masterGroupOrder and masterGroupOrder[a]) or math.huge
        local bo = tonumber(masterGroupOrder and masterGroupOrder[b]) or math.huge
        if ao ~= bo then return ao < bo end
        return tostring(a):lower() < tostring(b):lower()
    end)
    return groups
end

local function sortPoseRecords(records)
    table.sort(records, function(a, b)
        local ao, bo = poseOrder(a.scenario), poseOrder(b.scenario)
        if ao ~= bo then return ao < bo end
        if tostring(a.scenario) ~= tostring(b.scenario) then
            return tostring(a.scenario):lower() < tostring(b.scenario):lower()
        end
        return (tonumber(a.number) or 0) < (tonumber(b.number) or 0)
    end)
end

local function encodeBucket(lines, bucket, indent, prefix)
    local groups = orderedPoseGroups(bucket)
    if #groups == 0 then lines[#lines + 1] = indent .. prefix .. '{}' return end
    lines[#lines + 1] = indent .. prefix .. '{'
    for groupIndex, groupName in ipairs(groups) do
        local groupIndent = indent .. '  '
        lines[#lines + 1] = groupIndent .. json.encode(groupName) .. ': ['
        sortPoseRecords(bucket[groupName])
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

local function libraryPointGroups(library)
    local found = {}
    for pointGroup in pairs(library.pointGroupNames or {}) do found[pointGroup] = true end
    for _, pointGroup in ipairs(library.pointGroups or {}) do found[pointGroup or DEFAULT_POINT_GROUP] = true end
    for scenarioName, pointGroup in pairs(library.posePointGroups or {}) do
        if scenarioName then found[pointGroup or DEFAULT_POINT_GROUP] = true end
    end
    if next(found) == nil then found[DEFAULT_POINT_GROUP] = true end
    return sortedKeys(found)
end

local function groupedPoseBucket(library, pointGroup, visibility)
    local result = {}
    for scenarioGroup, records in pairs(library.poses[visibility] or {}) do
        for _, record in ipairs(records) do
            if ((library.posePointGroups or {})[record.scenario] or DEFAULT_POINT_GROUP) == pointGroup then
                result[scenarioGroup] = result[scenarioGroup] or {}
                result[scenarioGroup][#result[scenarioGroup] + 1] = record
            end
        end
    end
    return result
end

local function encodeLibraries(values)
    local lines = { '[' }
    for libraryIndex, library in ipairs(values) do
        if library.preset then
            lines[#lines + 1] = ('  { "item": %s, "preset": %s }%s'):format(
                json.encode(library.item), json.encode(library.preset), libraryIndex < #values and ',' or '')
        else
        local pointGroups = libraryPointGroups(library)
        lines[#lines + 1] = '  {'
        lines[#lines + 1] = '    "item": ' .. json.encode(library.item) .. ','
        lines[#lines + 1] = '    "offsets": {'
        for groupIndex, pointGroup in ipairs(pointGroups) do
            lines[#lines + 1] = '      ' .. json.encode(pointGroup) .. ': ['
            local groupedOffsets = {}
            for offsetIndex, offset in ipairs(library.offsets) do
                if (library.pointGroups[offsetIndex] or DEFAULT_POINT_GROUP) == pointGroup then groupedOffsets[#groupedOffsets + 1] = offset end
            end
            for offsetIndex, offset in ipairs(groupedOffsets) do
                local comma = offsetIndex < #groupedOffsets and ',' or ''
                lines[#lines + 1] = ('        { "x": %s, "y": %s, "z": %s, "heading": %s }%s'):format(
                    json.encode(offset.x), json.encode(offset.y), json.encode(offset.z), json.encode(offset.heading), comma)
            end
            lines[#lines + 1] = '      ]' .. (groupIndex < #pointGroups and ',' or '')
        end
        lines[#lines + 1] = '    },'
        lines[#lines + 1] = '    "poses": {'
        for groupIndex, pointGroup in ipairs(pointGroups) do
            lines[#lines + 1] = '      ' .. json.encode(pointGroup) .. ': {'
            encodeBucket(lines, groupedPoseBucket(library, pointGroup, 'show'), '        ', '"show": ')
            lines[#lines] = lines[#lines] .. ','
            encodeBucket(lines, groupedPoseBucket(library, pointGroup, 'noshow'), '        ', '"noshow": ')
            lines[#lines + 1] = '      }' .. (groupIndex < #pointGroups and ',' or '')
        end
        lines[#lines + 1] = '    }'
        lines[#lines + 1] = '  }' .. (libraryIndex < #values and ',' or '')
        end
    end
    lines[#lines + 1] = ']'
    return table.concat(lines, '\n')
end
local function encodePresets()
    local names = sortedKeys(presets)
    local lines = { '[' }
    for index, name in ipairs(names) do
        local encoded = encodeLibraries({ presets[name] })
        encoded = encoded:match('^%[%s*(.-)%s*%]$') or '{}'
        encoded = encoded:gsub('"item"%s*:%s*[-%d%.]+', '"name": ' .. json.encode(name), 1)
        lines[#lines + 1] = encoded .. (index < #names and ',' or '')
    end
    lines[#lines + 1] = ']'
    return table.concat(lines, '\n')
end

local function encodeItems()
    local keys = sortedKeys(libraries)
    local lines = { '{' }
    for index, key in ipairs(keys) do
        local saved = libraries[key]
        local assignment = saved.offset and { saved.preset, saved.offset } or saved.preset
        lines[#lines + 1] = ('  %s: %s%s'):format(
            json.encode(tostring(saved.item)), json.encode(assignment), index < #keys and ',' or '')
    end
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n')
end

local function encodeCache()
    local presetJson = encodePresets():gsub('\n', '\n  ')
    local itemJson = encodeItems():gsub('\n', '\n  ')
    return '{\n  "presets": ' .. presetJson .. ',\n  "items": ' .. itemJson .. '\n}\n'
end
local function saveLibraries()
    if not SaveResourceFile(resourceName, cacheFile, encodeCache(), -1) then
        print(('[%s] Failed to save presets and object pose libraries to %s.'):format(resourceName, cacheFile))
        return false
    end
    return true
end
local function loadPoseOffsets()
    local contents = LoadResourceFile(resourceName, poseOffsetFile)
    if not contents or contents == '' then return end
    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then
        print(('[%s] Could not decode %s; starting with no global pose offsets.'):format(resourceName, poseOffsetFile))
        return
    end
    for scenarioName, value in pairs(decoded) do
        if type(scenarioName) == 'string' then
            local clean = normaliseOffset(value)
            if clean then poseOffsets[scenarioName] = clean end
        end
    end
end

local function encodePoseOffsets()
    local scenarios = sortedKeys(poseOffsets)
    if #scenarios == 0 then return '{}\n' end
    local lines = { '{' }
    for index, scenarioName in ipairs(scenarios) do
        local offset = poseOffsets[scenarioName]
        local comma = index < #scenarios and ',' or ''
        lines[#lines + 1] = ('  %s: { "x": %s, "y": %s, "z": %s, "heading": %s }%s'):format(
            json.encode(scenarioName),
            json.encode(offset.x),
            json.encode(offset.y),
            json.encode(offset.z),
            json.encode(offset.heading),
            comma
        )
    end
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n') .. '\n'
end

local function savePoseOffsets()
    if not SaveResourceFile(resourceName, poseOffsetFile, encodePoseOffsets(), -1) then
        print(('[%s] Failed to save global pose offsets to %s.'):format(resourceName, poseOffsetFile))
        return false
    end
    return true
end

local function hasConfiguredJob(source, configuredJobs)
    local core = getCore()
    local player = core and core.Functions.GetPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if type(job) ~= 'table' or job.onduty ~= true then return false end
    for _, jobName in ipairs(configuredJobs or {}) do
        if job.name == jobName then return true end
    end
    return false
end

local function canManage(source)
    return hasConfiguredJob(source, ConfigTarget.AdminJobs)
end

local function canEditPoseOffsets(source)
    return hasConfiguredJob(source, ConfigTarget.ReviewJobs)
end

if loadLibraries() then saveLibraries() end
loadPoseOffsets()

lib.callback.register('nt_actions:server:getTargetAccess', function(source)
    local models = {}
    for _, saved in pairs(libraries) do
        local model = type(saved) == 'table' and tonumber(saved.item) or nil
        if model then models[#models + 1] = model end
    end
    table.sort(models)
    return {
        models = models,
        canTargetUnregistered = canManage(source),
    }
end)

lib.callback.register('nt_actions:server:getObjectLibrary', function(source, model)
    if not validModel(model) then
        return { library = nil, canDelete = false }
    end
    return {
        library = getLibrary(model, false),
        preset = presetForModel(model),
        objectOffset = objectOffsetForModel(model),
        canDelete = canManage(source),
        canEditPoseOffsets = canEditPoseOffsets(source),
        poseOffsets = poseOffsets,
    }
end)

lib.callback.register('nt_actions:server:getPresets', function(source, model)
    if not canManage(source) or not validModel(model) then return false end
    local result = {}
    for _, name in ipairs(sortedKeys(presets)) do
        result[#result + 1] = { name = name, library = presets[name] }
    end
    return { presets = result, active = presetForModel(model) }
end)

lib.callback.register('nt_actions:server:applyObjectPreset', function(source, model, name)
    if not canManage(source) or not validModel(model) or type(name) ~= 'string' or not presets[name] then return false end
    local key, previous = tostring(model), libraries[tostring(model)]
    libraries[key] = { item = model, preset = name, offset = previous and previous.offset or nil }
    if not saveLibraries() then libraries[key] = previous return false end
    broadcastLibraryUpdate(model)
    return true
end)

lib.callback.register('nt_actions:server:removeObjectPreset', function(source, model, name)
    if not canManage(source) or not validModel(model) then return false end
    local key = tostring(model)
    local previous = libraries[key]
    if not previous or previous.preset ~= name then return false end
    libraries[key] = nil
    if not saveLibraries() then libraries[key] = previous return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return true
end)
lib.callback.register('nt_actions:server:renamePreset', function(source, oldName, requestedName)
    if not canManage(source) or type(oldName) ~= 'string' then return false end
    local name = cleanPresetName(requestedName)
    if not name or not presets[oldName] then return false end
    if name == oldName then return true end
    for existingName in pairs(presets) do
        if existingName ~= oldName and existingName:lower() == name:lower() then return false end
    end

    local library = presets[oldName]
    local affected = {}
    presets[name] = library
    presets[oldName] = nil
    for key, saved in pairs(libraries) do
        if saved.preset == oldName then
            saved.preset = name
            affected[#affected + 1] = tonumber(key)
        end
    end
    if not saveLibraries() then
        presets[oldName] = library
        presets[name] = nil
        for _, model in ipairs(affected) do libraries[tostring(model)].preset = oldName end
        saveLibraries()
        return false
    end
    for _, model in ipairs(affected) do
        TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    end
    return true
end)
lib.callback.register('nt_actions:server:getPoseOffsets', function()
    return poseOffsets
end)

lib.callback.register('nt_actions:server:savePoseOffset', function(source, groupName, scenarioName, value)
    if not validScenario(groupName, scenarioName) or not canEditPoseOffsets(source) then return false end
    local clean = normaliseOffset(value)
    if not clean then return false end

    local previous = poseOffsets[scenarioName]
    local isZero = math.abs(clean.x) <= 0.0001 and math.abs(clean.y) <= 0.0001
        and math.abs(clean.z) <= 0.0001 and (math.abs(clean.heading) <= 0.0001 or math.abs(clean.heading - 360.0) <= 0.0001)
    poseOffsets[scenarioName] = not isZero and clean or nil
    if not savePoseOffsets() then
        poseOffsets[scenarioName] = previous
        return false
    end
    TriggerClientEvent('nt_actions:client:poseOffsetUpdated', -1, scenarioName, poseOffsets[scenarioName])
    return { offset = poseOffsets[scenarioName] }
end)

lib.callback.register('nt_actions:server:saveObjectOffset', function(source, model, value)
    if not validModel(model) or not canManage(source) then return false end
    local saved = libraries[tostring(model)]
    if not saved or not saved.preset then return false end
    local clean = normaliseOffset(value)
    if not clean then return false end
    local previous = saved.offset
    local isZero = math.abs(clean.x) <= 0.0001 and math.abs(clean.y) <= 0.0001
        and math.abs(clean.z) <= 0.0001 and math.abs(clean.heading) <= 0.0001
    saved.offset = not isZero and clean or nil
    if not saveLibraries() then saved.offset = previous return false end
    TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model)
    return { offset = saved.offset }
end)
lib.callback.register('nt_actions:server:saveObjectPose', function(source, model, groupName, scenarioName, value, mode, coordNumber, separate, pointGroup, presetName)
    if not validModel(model) or not validScenario(groupName, scenarioName) then return false end
    local cleanOffset = normaliseOffset(value)
    if not cleanOffset then return false end
    mode = mode == 'modify' and 'modify' or 'add'
    coordNumber = tonumber(coordNumber)
    if coordNumber == 0 then coordNumber = nil end
    separate = separate == true
    pointGroup = type(pointGroup) == 'string' and pointGroup ~= '' and pointGroup or DEFAULT_POINT_GROUP

    if not canManage(source) then return false end
    local library = ensureItemPreset(model, presetName)
    if not library then return { needsPreset = true } end

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
        selectedOffset = selectedOffset or offsetNumber(library, cleanOffset, pointGroup)
    end
    pointGroup = library.pointGroups[selectedOffset] or pointGroup
    if not shown then addRecord(library, 'show', groupName, scenarioName, nil, nil, pointGroup) end
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
    return { coordNumber = selectedOffset }
end)

lib.callback.register('nt_actions:server:bulkAddObjectPoses', function(source, model, selections, pointGroup, presetName)
    if not validModel(model) or not canManage(source) or type(selections) ~= 'table'
    then
        return false
    end
    local library = ensureItemPreset(model, presetName)
    if not library then return { needsPreset = true } end
    pointGroup = type(pointGroup) == 'string' and pointGroup ~= '' and pointGroup or DEFAULT_POINT_GROUP
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

    if #pending == 0 then
        if not saveLibraries() then return false end
        broadcastLibraryUpdate(model)
        return { added = 0, skipped = skipped }
    end
    if #library.offsets == 0 then
        local defaultPoint = normaliseOffset(ConfigTarget.DefaultOffset or {})
        if not defaultPoint then return false end
        offsetNumber(library, defaultPoint, pointGroup)
    end
    for _, selection in ipairs(pending) do
        addRecord(library, 'show', selection.group, selection.scenario, nil, nil, pointGroup)
    end
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
    return { added = #pending, skipped = skipped }
end)

lib.callback.register('nt_actions:server:hideObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getEditableLibrary(model, false)
    local _, index = findRecord(library, 'show', groupName, scenarioName)
    if not index then return false end
    local record = removeRecord(library, 'show', groupName, index)
    addRecord(library, 'noshow', groupName, record.scenario)
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
    return true
end)

lib.callback.register('nt_actions:server:restoreObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getEditableLibrary(model, false)
    local _, index = findRecord(library, 'noshow', groupName, scenarioName)
    if not index then return false end
    local record = removeRecord(library, 'noshow', groupName, index)
    addRecord(library, 'show', groupName, record.scenario)
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
    return true
end)

lib.callback.register('nt_actions:server:deleteHiddenObjectPose', function(source, model, groupName, scenarioName, poseNumber)
    if not validModel(model) or not validScenario(groupName, scenarioName) or not canManage(source) then return false end
    local library = getEditableLibrary(model, false)
    local _, index = findRecord(library, 'noshow', groupName, scenarioName)
    if not index then return false end
    removeRecord(library, 'noshow', groupName, index)
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
    return true
end)

lib.callback.register('nt_actions:server:savePointGroups', function(source, model, requestedGroups)
    if not validModel(model) or not canManage(source) or type(requestedGroups) ~= 'table' then return false end
    local library = getEditableLibrary(model, false)
    if not library or #requestedGroups < 1 or #requestedGroups > 64 then return false end

    local expectedPoses = {}
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for scenarioGroup, records in pairs(library.poses[visibility] or {}) do
            for _, record in ipairs(records) do
                expectedPoses[scenarioGroup .. '\0' .. record.scenario] = record.scenario
            end
        end
    end

    local names, pointAssignments, poseAssignments = {}, {}, {}
    local pointSeen, poseSeen = {}, {}
    for groupIndex, requested in ipairs(requestedGroups) do
        if type(requested) ~= 'table' then return false end
        local name = type(requested.name) == 'string' and requested.name:match('^%s*(.-)%s*$') or nil
        if not name or name == '' or #name > 64 or names[name:lower()] then return false end
        names[name:lower()] = true
        local pointCount, poseCount = 0, 0

        for _, value in ipairs(type(requested.points) == 'table' and requested.points or {}) do
            local offsetIndex = tonumber(value)
            if not offsetIndex or offsetIndex % 1 ~= 0 or not library.offsets[offsetIndex] or pointSeen[offsetIndex] then
                return false
            end
            pointSeen[offsetIndex] = true
            pointAssignments[offsetIndex] = name
            pointCount = pointCount + 1
        end

        for _, value in ipairs(type(requested.poses) == 'table' and requested.poses or {}) do
            local scenarioGroup = type(value) == 'table' and value.group or nil
            local scenarioName = type(value) == 'table' and value.scenario or nil
            local key = tostring(scenarioGroup) .. '\0' .. tostring(scenarioName)
            if not expectedPoses[key] or poseSeen[key] or not validScenario(scenarioGroup, scenarioName) then return false end
            poseSeen[key] = true
            poseAssignments[scenarioName] = name
            poseCount = poseCount + 1
        end
        if poseCount > 0 and pointCount == 0 then return false end
    end

    for offsetIndex in ipairs(library.offsets) do if not pointSeen[offsetIndex] then return false end end
    for key in pairs(expectedPoses) do if not poseSeen[key] then return false end end

    local previousPointGroups, previousPointGroupNames, previousPosePointGroups =
        library.pointGroups, library.pointGroupNames, library.posePointGroups
    local pointGroupNames = {}
    for _, requested in ipairs(requestedGroups) do pointGroupNames[requested.name:match('^%s*(.-)%s*$')] = true end
    library.pointGroups, library.pointGroupNames, library.posePointGroups =
        pointAssignments, pointGroupNames, poseAssignments
    if not saveLibraries() then
        library.pointGroups, library.pointGroupNames, library.posePointGroups =
            previousPointGroups, previousPointGroupNames, previousPosePointGroups
        return false
    end
    broadcastLibraryUpdate(model)
    return true
end)
lib.callback.register('nt_actions:server:deleteObjectPoint', function(source, model, offsetIndex)
    if not validModel(model) or not canManage(source) then return false end
    local library = getEditableLibrary(model, false)
    if not library then return false end
    offsetIndex = tonumber(offsetIndex)
    if not offsetIndex or not library.offsets[offsetIndex] then return false end
    local pointGroup = library.pointGroups[offsetIndex] or DEFAULT_POINT_GROUP
    local groupPointCount = 0
    for index in ipairs(library.offsets) do
        local savedGroup = library.pointGroups[index] or DEFAULT_POINT_GROUP
        if savedGroup == pointGroup then groupPointCount = groupPointCount + 1 end
    end
    local groupHasPoses = false
    for scenarioName, savedGroup in pairs(library.posePointGroups) do
        if scenarioName and savedGroup == pointGroup then groupHasPoses = true break end
    end
    if groupHasPoses and groupPointCount <= 1 then return false end
    if not removeOffset(library, offsetIndex) then return false end
    if not saveLibraries() then return false end
    broadcastLibraryUpdate(model)
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

function NtActionsLibrary.getPresetReviewState()
    local presetCopies, assignments = {}, {}
    for name, library in pairs(presets) do
        local ok, copy = pcall(json.decode, json.encode(library))
        if ok and type(copy) == 'table' then presetCopies[name] = copy end
    end
    for key, saved in pairs(libraries) do
        assignments[tonumber(key)] = saved.preset or false
    end
    return { presets = presetCopies, assignments = assignments }
end

function NtActionsLibrary.commitComparedPreset(candidateLibrary, existingName, replacePreset, checkedPoses, objectModels, candidateName)
    candidateName = cleanPresetName(candidateName)
    existingName = cleanPresetName(existingName)
    if not candidateName or type(candidateLibrary) ~= 'table' or type(objectModels) ~= 'table' then return false end
    local destinationName = replacePreset and candidateName or existingName
    if not destinationName or (not replacePreset and not presets[destinationName]) then return false end
    if replacePreset and presets[candidateName] and candidateName ~= existingName then return false end

    local ok, candidateCopy = pcall(json.decode, json.encode(candidateLibrary))
    if not ok or type(candidateCopy) ~= 'table' then return false end
    candidateCopy.item = 0
    local cleanCandidate = normaliseLibrary(candidateCopy)
    if not cleanCandidate then return false end

    local previousPresets, previousLibraries = json.decode(json.encode(presets)), json.decode(json.encode(libraries))
    if replacePreset then
        presets[candidateName] = cleanCandidate
        if existingName and existingName ~= candidateName then presets[existingName] = nil end
        if existingName then
            for _, saved in pairs(libraries) do if saved.preset == existingName then saved.preset = candidateName end end
        end
    else
        local destination = presets[existingName]
        local requested = {}
        for _, value in ipairs(type(checkedPoses) == 'table' and checkedPoses or {}) do
            if type(value) == 'table' and validScenario(value.group, value.scenario) then
                requested[value.group .. '\0' .. value.scenario] = true
            end
        end
        for _, visibility in ipairs({ 'show', 'noshow' }) do
            for groupName, records in pairs(cleanCandidate.poses[visibility] or {}) do
                for _, record in ipairs(records) do
                    local key = groupName .. '\0' .. record.scenario
                    if requested[key] and not findRecord(destination, 'show', groupName, record.scenario)
                        and not findRecord(destination, 'noshow', groupName, record.scenario)
                    then
                        local pointGroup = cleanCandidate.posePointGroups[record.scenario] or DEFAULT_POINT_GROUP
                        destination.pointGroupNames[pointGroup] = true
                        for index, offset in ipairs(cleanCandidate.offsets) do
                            if (cleanCandidate.pointGroups[index] or DEFAULT_POINT_GROUP) == pointGroup then
                                offsetNumber(destination, normaliseOffset(offset), pointGroup)
                            end
                        end
                        addRecord(destination, visibility, groupName, record.scenario, nil, nil, pointGroup)
                    end
                end
            end
        end
    end

    local affected = {}
    for _, model in ipairs(objectModels) do
        model = tonumber(model)
        if validModel(model) then
            local previous = libraries[tostring(model)]
            libraries[tostring(model)] = {
                item = model, preset = destinationName, offset = previous and previous.offset or nil
            }
            affected[model] = true
        end
    end
    if replacePreset and existingName then
        for key, saved in pairs(libraries) do if saved.preset == destinationName then affected[tonumber(key)] = true end end
    else
        for key, saved in pairs(libraries) do if saved.preset == destinationName then affected[tonumber(key)] = true end end
    end
    if not saveLibraries() then
        presets, libraries = previousPresets, previousLibraries
        saveLibraries()
        return false
    end
    local models = {}
    for model in pairs(affected) do models[#models + 1] = model; TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, model) end
    table.sort(models)
    return { affectedModels = models, objectsLinked = #objectModels }
end
