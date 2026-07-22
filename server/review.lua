local resourceName = GetCurrentResourceName()
local settings = ConfigTarget.BatchReview or {}
local reviewFile = settings.File or 'object_offsets review.json'
local cleanedContents
local activeSource
local activeUntil = 0
local reviewLibraries = {}

local function authorized(source)
    return NtActionsLibrary
        and NtActionsLibrary.hasConfiguredJob(source, ConfigTarget.ReviewJobs) == true
end

local function readReviewFile()
    return LoadResourceFile(resourceName, reviewFile) or ''
end

local function decodeReview(contents)
    if contents == '' then return {}, false end
    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then return nil, false end
    local result, migrated = {}, false
    for _, value in ipairs(decoded) do
        -- Review records temporarily retain pose/coordinate associations so each
        -- imported placement can be previewed before the live library separates them.
        local library, changed = NtActionsLibrary.normaliseLibrary(value, true)
        if library then result[#result + 1] = library end
        migrated = changed or migrated
    end
    return result, migrated
end

local function recordCount(libraries)
    local items, poses, coords = 0, 0, 0
    for _, library in ipairs(libraries or {}) do
        local poseKeys = {}
        for _, visibility in ipairs({ 'show', 'noshow' }) do
            for groupName, records in pairs(library.poses[visibility] or {}) do
                for _, record in ipairs(records) do poseKeys[groupName .. '\0' .. record.scenario] = true end
            end
        end
        local itemPoses = 0
        for _ in pairs(poseKeys) do itemPoses = itemPoses + 1 end
        if itemPoses > 0 then
            items = items + 1
            poses = poses + itemPoses
            coords = coords + #(library.offsets or {})
        end
    end
    return items, poses, coords
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function scenarioGender(groupName, scenarioName)
    local group = ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[groupName]
    if not group then return nil end
    local function findGender(entries)
        for _, entry in ipairs(entries or {}) do
            if entry[1] == scenarioName then
                return entry[2] == 'male' and 'male' or entry[2] == 'female' and 'female' or nil
            end
        end
    end
    local gender = findGender(group.Poses)
    if gender then return gender end
    for _, entries in pairs(group.Scenarios or {}) do
        gender = findGender(entries)
        if gender then return gender end
    end
end

local function cleanReview(libraries)
    local removed = 0
    local cleaned = {}
    for _, library in ipairs(libraries or {}) do
        local output = { item = library.item, offsets = {}, poses = { show = {}, noshow = {} } }
        local live = NtActionsLibrary.getReviewState(library.item)
        local keptOffsets = {}
        local accepted = {}
        for _, groupName in ipairs(sortedKeys(library.poses.show)) do
            for _, record in ipairs(library.poses.show[groupName] or {}) do
                local offset = library.offsets[tonumber(record.offset)]
                local duplicate = false
                if offset then
                    for _, saved in ipairs(accepted) do
                        if saved.group == groupName and saved.scenario == record.scenario
                            and NtActionsLibrary.sameOffset(saved.offset, offset)
                        then
                            duplicate = true
                            break
                        end
                    end
                end
                local poseKey = groupName .. '\0' .. record.scenario
                if not offset or duplicate or live.poses[poseKey] ~= nil
                then
                    removed = removed + 1
                else
                    local oldIndex = tonumber(record.offset)
                    local newIndex = keptOffsets[oldIndex]
                    if not newIndex then
                        for index, savedOffset in ipairs(output.offsets) do
                            if NtActionsLibrary.sameOffset(savedOffset, offset) then
                                newIndex = index
                                break
                            end
                        end
                    end
                    if not newIndex then
                        output.offsets[#output.offsets + 1] = offset
                        newIndex = #output.offsets
                    end
                    if oldIndex then
                        keptOffsets[oldIndex] = newIndex
                    end
                    output.poses.show[groupName] = output.poses.show[groupName] or {}
                    output.poses.show[groupName][#output.poses.show[groupName] + 1] = {
                        scenario = record.scenario,
                        number = record.number,
                        offset = newIndex,
                    }
                    accepted[#accepted + 1] = { group = groupName, scenario = record.scenario, offset = offset }
                end
            end
        end
        for _, records in pairs(library.poses.noshow or {}) do removed = removed + #records end
        for _, records in pairs(output.poses.show) do
            local byScenario = {}
            for _, record in ipairs(records) do
                byScenario[record.scenario] = byScenario[record.scenario] or {}
                byScenario[record.scenario][#byScenario[record.scenario] + 1] = record
            end
            for _, matches in pairs(byScenario) do
                if #matches == 1 then
                    matches[1].number = nil
                else
                    for index, record in ipairs(matches) do record.number = index end
                end
            end
        end
        if next(output.poses.show) ~= nil then cleaned[#cleaned + 1] = output end
    end
    table.sort(cleaned, function(a, b) return a.item < b.item end)
    return cleaned, removed
end

local function compactReviewLibraries(libraries)
    local compact = {}
    for _, library in ipairs(libraries or {}) do
        local output = {
            item = library.item,
            offsets = library.offsets or {},
            poses = { show = {}, noshow = {} },
        }
        for _, visibility in ipairs({ 'show', 'noshow' }) do
            for groupName, records in pairs(library.poses[visibility] or {}) do
                local seen = {}
                for _, record in ipairs(records) do
                    if not seen[record.scenario] then
                        seen[record.scenario] = true
                        output.poses[visibility][groupName] = output.poses[visibility][groupName] or {}
                        output.poses[visibility][groupName][#output.poses[visibility][groupName] + 1] = {
                            scenario = record.scenario,
                        }
                    end
                end
            end
        end
        compact[#compact + 1] = output
    end
    return compact
end

local function writeReview(libraries)
    local encoded = NtActionsLibrary.encodeLibraries(compactReviewLibraries(libraries))
    if not SaveResourceFile(resourceName, reviewFile, encoded, -1) then return false end
    local persisted = decodeReview(encoded)
    if not persisted then return false end
    cleanedContents = encoded
    reviewLibraries = persisted
    return true
end

local function buildPages()
    local pages, nextId = {}, 0
    for _, library in ipairs(reviewLibraries) do
        local live = NtActionsLibrary.getReviewState(library.item)
        local page = {
            key = tostring(library.item),
            item = library.item,
            poses = {},
            currentCoords = live.offsets or {},
            newCoords = {},
            _library = library,
        }
        local poseKeys = {}
        for _, groupName in ipairs(sortedKeys(library.poses.show)) do
            for _, record in ipairs(library.poses.show[groupName]) do
                local offset = library.offsets[record.offset]
                local poseKey = groupName .. '\0' .. record.scenario
                local isNewPose = live.poses[poseKey] == nil
                if isNewPose and not poseKeys[poseKey] then
                    poseKeys[poseKey] = true
                    nextId = nextId + 1
                    page.poses[#page.poses + 1] = {
                        id = nextId,
                        group = groupName,
                        scenario = record.scenario,
                        gender = scenarioGender(groupName, record.scenario),
                        current = false,
                    }
                end
                if isNewPose and offset then
                    local current = false
                    for _, liveOffset in ipairs(live.offsets or {}) do
                        if NtActionsLibrary.sameOffset(liveOffset, offset) then current = true break end
                    end
                    if not current then
                        local duplicate = false
                        for _, candidate in ipairs(page.newCoords) do
                            if NtActionsLibrary.sameOffset(candidate.offset, offset) then duplicate = true break end
                        end
                        if not duplicate then
                            nextId = nextId + 1
                            page.newCoords[#page.newCoords + 1] = {
                                id = nextId,
                                offset = offset,
                            }
                        end
                    end
                end
            end
        end
        if #page.poses > 0 then pages[#pages + 1] = page end
    end
    return pages
end

local function publicPages()
    local result = {}
    for _, page in ipairs(buildPages()) do
        local copy = {
            key = page.key,
            item = page.item,
            poses = {},
            currentCoords = page.currentCoords,
            newCoords = {},
        }
        for _, pose in ipairs(page.poses) do
            copy.poses[#copy.poses + 1] = {
                id = pose.id,
                group = pose.group,
                scenario = pose.scenario,
                gender = pose.gender,
                current = pose.current,
                visibility = pose.visibility,
            }
        end
        for _, coord in ipairs(page.newCoords) do
            copy.newCoords[#copy.newCoords + 1] = { id = coord.id, offset = coord.offset }
        end
        result[#result + 1] = copy
    end
    return result
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
    local libraries = decodeReview(contents)
    local items, poses, coords = recordCount(libraries)
    return {
        authorized = true,
        hasData = poses > 0,
        clean = poses > 0 and cleanedContents ~= nil and contents == cleanedContents,
        items = items,
        poses = poses,
        coords = coords,
        busy = activeSource ~= nil and activeSource ~= source,
    }
end)

lib.callback.register('nt_actions:server:cleanupReview', function(source)
    if not authorized(source) or (activeSource and activeSource ~= source) then return false end
    local contents = readReviewFile()
    local libraries = decodeReview(contents)
    if not libraries then return false end
    local beforeItems, beforePoses, beforeCoords = recordCount(libraries)
    local cleaned, removed = cleanReview(libraries)
    if not writeReview(cleaned) then return false end
    local items, poses, coords = recordCount(cleaned)
    return {
        beforeItems = beforeItems,
        beforePoses = beforePoses,
        beforeCoords = beforeCoords,
        items = items,
        poses = poses,
        coords = coords,
        removed = removed,
    }
end)

lib.callback.register('nt_actions:server:startReview', function(source)
    if not authorized(source) then return false end
    if activeSource and activeSource ~= source then return { busy = true } end
    local contents = readReviewFile()
    if not cleanedContents or contents ~= cleanedContents then return { needsCleanup = true } end
    local libraries = decodeReview(contents)
    if not libraries then return false end
    reviewLibraries = libraries
    activeSource = source
    touch(source)
    return { pages = publicPages() }
end)

lib.callback.register('nt_actions:server:submitReviewGroup', function(
    source, pageKey, approvedPoseIds, approvedCoordIds, reviewerGender)
    if not authorized(source) or not touch(source) then return false end
    if reviewerGender ~= 'male' and reviewerGender ~= 'female' then return false end
    local approvedPoses, approvedCoords = {}, {}
    for _, id in ipairs(type(approvedPoseIds) == 'table' and approvedPoseIds or {}) do
        approvedPoses[tonumber(id)] = true
    end
    for _, id in ipairs(type(approvedCoordIds) == 'table' and approvedCoordIds or {}) do
        approvedCoords[tonumber(id)] = true
    end
    local target
    for _, page in ipairs(buildPages()) do if page.key == pageKey then target = page break end end
    if not target then return false end

    local posesMerged, coordsMerged = 0, 0
    local posesProcessed = 0
    for _, coord in ipairs(target.newCoords) do
        if approvedCoords[coord.id] and NtActionsLibrary.mergeReviewedPoint(target.item, coord.offset) then
            coordsMerged = coordsMerged + 1
        end
    end
    for _, pose in ipairs(target.poses) do
        local compatible = not pose.gender or pose.gender == reviewerGender
        if compatible and not pose.current then
            posesProcessed = posesProcessed + 1
            if approvedPoses[pose.id]
                and NtActionsLibrary.mergeReviewedPose(target.item, pose.group, pose.scenario)
            then
                posesMerged = posesMerged + 1
            end
        end
    end
    if posesMerged > 0 or coordsMerged > 0 then
        if not NtActionsLibrary.save() then return false end
        TriggerClientEvent('nt_actions:client:objectLibraryUpdated', -1, target.item)
    end

    local waitingPose
    for _, pose in ipairs(target.poses) do
        if pose.gender and pose.gender ~= reviewerGender then
            waitingPose = waitingPose or pose
        end
    end
    if waitingPose then
        local kept = {}
        for groupName, records in pairs(target._library.poses.show or {}) do
            for _, record in ipairs(records) do
                local gender = scenarioGender(groupName, record.scenario)
                if gender and gender ~= reviewerGender then
                    kept[groupName] = kept[groupName] or {}
                    kept[groupName][#kept[groupName] + 1] = record
                end
            end
        end
        target._library.poses.show = kept

        local waitingRecords = target._library.poses.show[waitingPose.group] or {}
        target._library.poses.show[waitingPose.group] = waitingRecords
        for offsetIndex in ipairs(target._library.offsets or {}) do
            local referenced = false
            for _, records in pairs(target._library.poses.show) do
                for _, record in ipairs(records) do
                    if tonumber(record.offset) == offsetIndex then referenced = true break end
                end
                if referenced then break end
            end
            if not referenced then
                waitingRecords[#waitingRecords + 1] = {
                    scenario = waitingPose.scenario,
                    offset = offsetIndex,
                }
            end
        end
    else
        for index, library in ipairs(reviewLibraries) do
            if library == target._library then
                table.remove(reviewLibraries, index)
                break
            end
        end
    end
    local remainingLibraries = cleanReview(reviewLibraries)
    if not writeReview(remainingLibraries) then return false end
    local pages = publicPages()
    if #pages == 0 then release(source) end
    return {
        posesMerged = posesMerged,
        posesProcessed = posesProcessed,
        coordsMerged = coordsMerged,
        coordsProcessed = #target.newCoords,
        waitingForGender = waitingPose and waitingPose.gender or nil,
        pages = pages,
    }
end)

lib.callback.register('nt_actions:server:endReview', function(source)
    release(source)
    return true
end)

AddEventHandler('playerDropped', function()
    release(source)
end)

CreateThread(function()
    while true do
        Wait(30000)
        if activeSource and GetGameTimer() > activeUntil then release(activeSource) end
    end
end)
