local resourceName = GetCurrentResourceName()
local settings = ConfigTarget.BatchReview or {}
local reviewFile = settings.File or 'object_offsets review.json'
local cleanedContents
local activeSource
local activeUntil = 0
local reviewPresets = {}
local reviewItems = {}

local function authorized(source)
    return NtActionsLibrary
        and NtActionsLibrary.hasConfiguredJob(source, ConfigTarget.ReviewJobs) == true
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function readReviewFile()
    return LoadResourceFile(resourceName, reviewFile) or ''
end

local function decodeReview(contents)
    if contents == '' then return {}, {}, 0 end
    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then return nil end
    local presetsByName, items, removed = {}, {}, 0
    for _, value in ipairs(type(decoded.presets) == 'table' and decoded.presets or {}) do
        if type(value) == 'table' and type(value.name) == 'string' and value.name ~= '' then
            local candidate = {}
            for key, entry in pairs(value) do candidate[key] = entry end
            candidate.item = 0
            local library = NtActionsLibrary.normaliseLibrary(candidate, false)
            if library then presetsByName[value.name] = library else removed = removed + 1 end
        else
            removed = removed + 1
        end
    end
    if type(decoded.items) == 'table' then
        for modelKey, presetName in pairs(decoded.items) do
            local model = tonumber(modelKey)
            if NtActionsLibrary.validModel(model) and type(presetName) == 'string' and presetName ~= '' then
                items[tostring(model)] = presetName
            else
                removed = removed + 1
            end
        end
    elseif type(decoded.objects) == 'table' then
        -- One-time compatibility for the earlier preset reference array.
        for _, value in ipairs(decoded.objects) do
            if type(value) == 'table' and NtActionsLibrary.validModel(value.item)
                and type(value.preset) == 'string' and value.preset ~= ''
            then
                items[tostring(value.item)] = value.preset
            else
                removed = removed + 1
            end
        end
    end
    return presetsByName, items, removed
end

local function encodePresets(values)
    local lines, names = { '[' }, sortedKeys(values)
    for index, name in ipairs(names) do
        local encoded = NtActionsLibrary.encodeLibraries({ values[name] })
        encoded = encoded:match('^%[%s*(.-)%s*%]$') or '{}'
        encoded = encoded:gsub('"item"%s*:%s*[-%d%.]+', '"name": ' .. json.encode(name), 1)
        lines[#lines + 1] = encoded .. (index < #names and ',' or '')
    end
    lines[#lines + 1] = ']'
    return table.concat(lines, '\n')
end

local function encodeItems(values)
    local lines, keys = { '{' }, sortedKeys(values)
    for index, key in ipairs(keys) do
        lines[#lines + 1] = ('  %s: %s%s'):format(
            json.encode(tostring(key)), json.encode(values[key]), index < #keys and ',' or '')
    end
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n')
end

local function writeReview(presetValues, itemValues)
    local presetJson = encodePresets(presetValues):gsub('\n', '\n  ')
    local itemJson = encodeItems(itemValues):gsub('\n', '\n  ')
    local encoded = '{\n  "presets": ' .. presetJson .. ',\n  "items": ' .. itemJson .. '\n}\n'
    if not SaveResourceFile(resourceName, reviewFile, encoded, -1) then return false end
    local persistedPresets, persistedItems = decodeReview(encoded)
    if not persistedPresets then return false end
    cleanedContents = encoded
    reviewPresets, reviewItems = persistedPresets, persistedItems
    return true
end

local function scenarioGender(groupName, scenarioName)
    local group = ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[groupName]
    if not group then return nil end
    local function find(entries)
        for _, entry in ipairs(entries or {}) do
            if entry[1] == scenarioName then
                return entry[3] == 'male' and 'male' or entry[3] == 'female' and 'female' or nil
            end
        end
    end
    local gender = find(group.Poses)
    if gender then return gender end
    for _, entries in pairs(group.Scenarios or {}) do
        gender = find(entries)
        if gender then return gender end
    end
end

local function publicDefinition(library)
    if type(library) ~= 'table' then return nil end
    local definition, seen = { currentCoords = {}, poses = {} }, {}
    for index, offset in ipairs(library.offsets or {}) do
        definition.currentCoords[#definition.currentCoords + 1] = {
            offset = offset,
            pointGroup = (library.pointGroups or {})[index] or 'Group 1',
        }
    end
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for groupName, records in pairs(library.poses[visibility] or {}) do
            for _, record in ipairs(records) do
                local key = groupName .. '\0' .. record.scenario
                if not seen[key] then
                    seen[key] = true
                    definition.poses[#definition.poses + 1] = {
                        group = groupName, scenario = record.scenario, visibility = visibility,
                        gender = scenarioGender(groupName, record.scenario),
                        pointGroup = (library.posePointGroups or {})[record.scenario] or 'Group 1',
                    }
                end
            end
        end
    end
    table.sort(definition.poses, function(a, b)
        if a.group ~= b.group then return a.group:lower() < b.group:lower() end
        return a.scenario:lower() < b.scenario:lower()
    end)
    return definition
end

local function buildPages()
    local live = NtActionsLibrary.getPresetReviewState()
    local names = {}
    for name in pairs(reviewPresets) do names[name] = true end
    for _, name in pairs(reviewItems) do names[name] = true end
    local pages = {}
    for _, candidateName in ipairs(sortedKeys(names)) do
        local objects = {}
        for modelKey, name in pairs(reviewItems) do
            if name == candidateName then
                local model = tonumber(modelKey)
                local assignment = live.assignments[model]
                objects[#objects + 1] = {
                    item = model,
                    currentPreset = type(assignment) == 'string' and assignment or nil,
                    hasLocalLibrary = assignment == false,
                }
            end
        end
        table.sort(objects, function(a, b) return a.item < b.item end)
        local destinations = {}
        if reviewPresets[candidateName] then
            destinations[#destinations + 1] = {
                name = candidateName, candidate = true,
                isNew = live.presets[candidateName] == nil,
                definition = publicDefinition(reviewPresets[candidateName]),
            }
        end
        for _, name in ipairs(sortedKeys(live.presets)) do
            local linkedItems = {}
            for model, assignedName in pairs(live.assignments or {}) do
                if assignedName == name then linkedItems[#linkedItems + 1] = tonumber(model) end
            end
            table.sort(linkedItems)
            destinations[#destinations + 1] = {
                name = name, candidate = false, isNew = false,
                definition = publicDefinition(live.presets[name]),
                items = linkedItems,
            }
        end
        if #destinations > 0 then
            pages[#pages + 1] = {
                key = candidateName, candidateName = candidateName,
                hasCandidate = reviewPresets[candidateName] ~= nil,
                candidateDefinition = publicDefinition(reviewPresets[candidateName]),
                destinations = destinations, objects = objects,
            }
        end
    end
    return pages
end

local function touch(source)
    if activeSource ~= source then return false end
    activeUntil = GetGameTimer() + (tonumber(settings.SessionTimeout) or 1800000)
    return true
end

local function release(source)
    if not source or activeSource == source then activeSource, activeUntil = nil, 0 end
end

lib.callback.register('nt_actions:server:reviewStatus', function(source)
    if not authorized(source) then return { authorized = false } end
    local contents = readReviewFile()
    local candidatePresets, candidateItems = decodeReview(contents)
    if not candidatePresets then return { authorized = true, invalid = true } end
    local presetCount = 0
    for _ in pairs(candidatePresets) do presetCount = presetCount + 1 end
    local itemCount = 0
    for _ in pairs(candidateItems) do itemCount = itemCount + 1 end
    return {
        authorized = true,
        hasData = presetCount > 0 or itemCount > 0,
        clean = (presetCount > 0 or itemCount > 0) and cleanedContents ~= nil and contents == cleanedContents,
        presets = presetCount,
        items = itemCount,
        busy = activeSource ~= nil and activeSource ~= source,
    }
end)

lib.callback.register('nt_actions:server:cleanupReview', function(source)
    if not authorized(source) or (activeSource and activeSource ~= source) then return false end
    local candidatePresets, candidateItems, removed = decodeReview(readReviewFile())
    if not candidatePresets then return false end
    local live = NtActionsLibrary.getPresetReviewState()
    local validItems = {}
    for modelKey, presetName in pairs(candidateItems) do
        if candidatePresets[presetName] or live.presets[presetName] then
            validItems[modelKey] = presetName
        else
            removed = removed + 1
        end
    end
    if not writeReview(candidatePresets, validItems) then return false end
    local presetCount, itemCount = 0, 0
    for _ in pairs(candidatePresets) do presetCount = presetCount + 1 end
    for _ in pairs(validItems) do itemCount = itemCount + 1 end
    return { presets = presetCount, items = itemCount, removed = removed }
end)

lib.callback.register('nt_actions:server:startPresetReview', function(source)
    if not authorized(source) then return false end
    if activeSource and activeSource ~= source then return { busy = true } end
    local contents = readReviewFile()
    if not cleanedContents or contents ~= cleanedContents then return { needsCleanup = true } end
    local candidatePresets, candidateItems = decodeReview(contents)
    if not candidatePresets then return false end
    reviewPresets, reviewItems = candidatePresets, candidateItems
    activeSource = source
    touch(source)
    return { pages = buildPages() }
end)

lib.callback.register('nt_actions:server:submitPresetCompare', function(
    source, candidateName, existingName, replacePreset, checkedPoses, checkedObjects)
    if not authorized(source) or not touch(source) then return false end
    local candidate = reviewPresets[candidateName]
    if not candidate then return false end
    local eligible, models = {}, {}
    for modelKey, name in pairs(reviewItems) do if name == candidateName then eligible[tonumber(modelKey)] = true end end
    for _, model in ipairs(type(checkedObjects) == 'table' and checkedObjects or {}) do
        model = tonumber(model)
        if eligible[model] then models[#models + 1] = model end
    end
    local result = NtActionsLibrary.commitComparedPreset(
        candidate, existingName, replacePreset == true, checkedPoses, models, candidateName)
    if type(result) ~= 'table' then return false end

    if replacePreset == true then
        reviewPresets[candidateName] = nil
    else
        local requested = {}
        for _, value in ipairs(type(checkedPoses) == 'table' and checkedPoses or {}) do
            if type(value) == 'table' then requested[tostring(value.group) .. '\0' .. tostring(value.scenario)] = true end
        end
        for _, visibility in ipairs({ 'show', 'noshow' }) do
            for groupName, records in pairs(candidate.poses[visibility] or {}) do
                local kept = {}
                for _, record in ipairs(records) do
                    if not requested[groupName .. '\0' .. record.scenario] then kept[#kept + 1] = record end
                end
                candidate.poses[visibility][groupName] = #kept > 0 and kept or nil
            end
        end
        if next(candidate.poses.show) == nil and next(candidate.poses.noshow) == nil then reviewPresets[candidateName] = nil end
    end
    for _, model in ipairs(models) do reviewItems[tostring(model)] = nil end
    if not writeReview(reviewPresets, reviewItems) then return false end
    result.pages = buildPages()
    if #result.pages == 0 then release(source) end
    return result
end)
lib.callback.register('nt_actions:server:endReview', function(source)
    release(source)
    return true
end)

AddEventHandler('playerDropped', function() release(source) end)

CreateThread(function()
    while true do
        Wait(30000)
        if activeSource and GetGameTimer() > activeUntil then release(activeSource) end
    end
end)