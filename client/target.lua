local TARGET_OPTION = 'nt_actions_object_poses'

local selectedObject
local selectedModel
local selectedGroup
local selectedScenario
local currentOffset
local DEFAULT_POINT_GROUP = 'Group 1'
local currentLibrary = { records = {}, offsets = {}, pointGroups = {}, pointGroupNames = {} }
local currentPreset
local poseOffsets = {}
local currentObjectOffset
local currentCoordOffsets = {}
local canDeleteGroups = false
local canEditPoseOffsets = false
local cachedTargetModels = {}
local canTargetUnregistered = false
local modModeActive = false
local activePose
local editorPreviousPose
local editorOrigin
local editorMode
local editorCoordNumber
local editorPointOffset
local editorScenarioInPlace = false
local availablePointOffsets = {}
local pointScanSession = 0
local selectedMenuCoord = 1
local objectMenuVisible = false
local fineTuneActive = false
local editorMoveSetActive = false
local editorOpening = false
local groupEditorActive = false
local presetEditorActive = false
local presetCache = {}
local cameraLookActive = false
local fineTuneCamera
local orbitRadius = 1.0
local orbitYaw = 0.0
local orbitPitch = 0.0
local posePropBaseline = {}
local trackedPoseProps = {}
local posePropTracking = false
local posePropCleanupPending = false
local posePropSession = 0

local openObjectMenu
local menuText = ConfigTarget.MenuText or {}
local editorSettings = ConfigTarget.PoseEditor or {}

local function configuredText(key, fallback)
    local value = menuText[key]
    return type(value) == 'string' and value ~= '' and value or fallback
end

local function leaveDebug(message, ...)
    if Config.Debug ~= true then return end
    local ok, formatted = pcall(string.format, message, ...)
    print(('[Nt_Actions][LeavePose] %s'):format(ok and formatted or message))
end

local function defaultEditorStep()
    return tonumber(editorSettings.DefaultStep) or 0.025
end

-- Shared client state for object targeting, pose playback, and review previews.
inPose = inPose == true
cachedPoseObject = cachedPoseObject or nil

local function setActivePose(pose)
    activePose = pose
    inPose = pose ~= nil
    cachedPoseObject = pose and pose.entity or nil
end

local function notify(description, notificationType)
    lib.notify({
        title = configuredText('ObjectTitle', 'Object Poses'),
        description = description,
        type = notificationType or 'inform',
    })
end

local function ensurePresetName()
    if type(currentPreset) == 'string' and currentPreset ~= '' then return currentPreset end
    local input = lib.inputDialog('Assign Object Preset', {
        { type = 'input', label = 'Preset name', description = 'Create a new preset or enter an existing preset name.', required = true, min = 1, max = 64 },
    })
    local name = input and type(input[1]) == 'string' and input[1]:match('^%s*(.-)%s*$') or nil
    if not name or name == '' then return nil end
    currentPreset = name
    return name
end
local function copyOffset(value)
    value = value or ConfigTarget.DefaultOffset or {}
    return {
        id = tonumber(value.id),
        x = tonumber(value.x) or 0.0,
        y = tonumber(value.y) or 0.0,
        z = tonumber(value.z) or 0.0,
        heading = tonumber(value.heading) or 0.0,
    }
end

local function coordOffsetFor(pointOffset)
    local id = pointOffset and tonumber(pointOffset.id)
    return id and currentCoordOffsets[tostring(id)] or nil
end

local function rotatePoseXY(adjustment, pointHeading)
    local radians = math.rad(tonumber(pointHeading) or 0.0)
    local cosine, sine = math.cos(radians), math.sin(radians)
    return
        (adjustment.x * cosine) - (adjustment.y * sine),
        (adjustment.x * sine) + (adjustment.y * cosine)
end

local function combinedOffset(pointOffset, poseOffset)
    local point = copyOffset(pointOffset)
    local adjustment = copyOffset(poseOffset or {})
    local x, y = rotatePoseXY(adjustment, point.heading)
    return {
        x = point.x + x,
        y = point.y + y,
        z = point.z + adjustment.z,
        heading = (point.heading + adjustment.heading) % 360.0,
    }
end

local function poseOffsetFor(scenarioName)
    return poseOffsets[scenarioName]
end

local function withoutPoseOffset(value, scenarioName)
    local offset = copyOffset(value)
    local adjustment = poseOffsetFor(scenarioName)
    if not adjustment then return offset end
    local pointHeading = (offset.heading - (tonumber(adjustment.heading) or 0.0)) % 360.0
    local x, y = rotatePoseXY(copyOffset(adjustment), pointHeading)
    offset.x = offset.x - x
    offset.y = offset.y - y
    offset.z = offset.z - (tonumber(adjustment.z) or 0.0)
    offset.heading = pointHeading
    return offset
end

local function withoutObjectOffset(value)
    local offset = copyOffset(value)
    if not currentObjectOffset then return offset end
    local adjustment = copyOffset(currentObjectOffset)
    local heading = math.rad(-(tonumber(adjustment.heading) or 0.0))
    local dx, dy = offset.x - adjustment.x, offset.y - adjustment.y
    offset.x = (dx * math.cos(heading)) - (dy * math.sin(heading))
    offset.y = (dx * math.sin(heading)) + (dy * math.cos(heading))
    offset.z = offset.z - adjustment.z
    offset.heading = (offset.heading - adjustment.heading) % 360.0
    return offset
end
local function sameOffset(a, b)
    if not a or not b then return false end
    local epsilon = 0.0001
    return math.abs((a.x or 0.0) - (b.x or 0.0)) <= epsilon
        and math.abs((a.y or 0.0) - (b.y or 0.0)) <= epsilon
        and math.abs((a.z or 0.0) - (b.z or 0.0)) <= epsilon
        and math.abs((a.heading or 0.0) - (b.heading or 0.0)) <= epsilon
end

local function copyTransform(value)
    if not value then return nil end
    return {
        x = tonumber(value.x) or 0.0,
        y = tonumber(value.y) or 0.0,
        z = tonumber(value.z) or 0.0,
        heading = tonumber(value.heading) or 0.0,
    }
end

local function pedTransform(ped)
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped),
    }
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function orderedGroups()
    local configured = ConfigGroups and ConfigGroups.Scenario or {}
    local result, included = {}, {}
    for _, groupName in ipairs(ConfigGroups and ConfigGroups.ScenarioOrder or {}) do
        if configured[groupName] then
            result[#result + 1] = groupName
            included[groupName] = true
        end
    end
    for _, groupName in ipairs(sortedKeys(configured)) do
        if not included[groupName] then result[#result + 1] = groupName end
    end
    return result
end

local function groupPoses(groupName)
    local group = ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[groupName]
    if not group then return {} end
    if type(group.Poses) == 'table' then return group.Poses end

    local poses = {}
    for _, category in pairs(group.Scenarios or {}) do
        for _, entry in ipairs(category) do poses[#poses + 1] = entry end
    end
    return poses
end

local function genderLock(entry)
    local lock = entry and entry[3]
    if lock == 'male' or lock == 'female' then return lock end
end

local function compatible(entry)
    local lock = genderLock(entry)
    if not lock then return true end
    local male = IsPedMale(PlayerPedId())
    return (lock == 'male' and male) or (lock == 'female' and not male)
end

local function prettyWords(value)
    value = tostring(value or ''):gsub('_', ' '):lower()
    return (value:gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest
    end))
end

local function poseLabel(groupName, entry)
    local name = entry[1]
    local custom = entry[2]
    if custom and custom ~= '' then return custom end

    local group = ConfigGroups.Scenario[groupName]
    for _, prefix in ipairs(group.truncate or {}) do
        if name:sub(1, #prefix) == prefix then return prettyWords(name:sub(#prefix + 1)) end
    end
    return prettyWords(name)
end

local function numberedPoseLabel(groupName, entry, poseNumber)
    local label = poseLabel(groupName, entry)
    return poseNumber and ('%s - %d'):format(label, poseNumber) or label
end

local function configuredEntry(groupName, scenarioName)
    for _, entry in ipairs(groupPoses(groupName)) do
        if entry[1] == scenarioName then return entry end
    end
end

local function objectExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function targetableObject(entity)
    return objectExists(entity) and GetEntityModel(entity) ~= 0
end

local function attachedObjects(ped)
    local attached = {}
    local objects = GetGamePool and GetGamePool('CObject') or {}
    for _, object in ipairs(objects) do
        if objectExists(object) and IsEntityAttachedToEntity(object, ped) then
            attached[object] = true
        end
    end
    return attached
end

local function beginPosePropTracking(ped)
    posePropSession = posePropSession + 1
    posePropBaseline = attachedObjects(ped)
    trackedPoseProps = {}
    posePropTracking = true
    posePropCleanupPending = false
end

local function scanPoseProps(ped)
    if not posePropTracking then return end
    for object in pairs(attachedObjects(ped)) do
        if not posePropBaseline[object] then trackedPoseProps[object] = true end
    end
end

local function deleteTrackedPoseProps(ped)
    scanPoseProps(ped)
    for object in pairs(trackedPoseProps) do
        if objectExists(object) then
            if NetworkGetEntityIsNetworked(object) then NetworkRequestControlOfEntity(object) end
            DetachEntity(object, true, true)
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            if objectExists(object) then DeleteEntity(object) end
        end
        trackedPoseProps[object] = nil
    end
end

local function finishPosePropCleanup(ped)
    if not posePropTracking then return end
    local session = posePropSession
    posePropCleanupPending = true
    deleteTrackedPoseProps(ped)
    CreateThread(function()
        Wait(math.max(0, math.floor(tonumber(ConfigTarget.PropCleanupDelay) or 250)))
        if session ~= posePropSession then return end
        deleteTrackedPoseProps(ped)
        posePropTracking = false
        posePropCleanupPending = false
        posePropBaseline = {}
        trackedPoseProps = {}
    end)
end

CreateThread(function()
    while true do
        Wait(posePropTracking and 100 or 500)
        if posePropTracking then scanPoseProps(PlayerPedId()) end
    end
end)

local function pointToObjectOffset(pointCoords, pointHeading)
    if not objectExists(selectedObject) then return nil end
    local objectCoords = GetEntityCoords(selectedObject)
    local heading = math.rad(GetEntityHeading(selectedObject))
    local dx, dy = pointCoords.x - objectCoords.x, pointCoords.y - objectCoords.y
    return {
        x = (dx * math.cos(heading)) + (dy * math.sin(heading)),
        y = (-dx * math.sin(heading)) + (dy * math.cos(heading)),
        z = pointCoords.z - objectCoords.z,
        heading = ((pointHeading or GetEntityHeading(PlayerPedId())) - GetEntityHeading(selectedObject)) % 360.0,
    }
end

local function scanPointOffsetsAtPlayer()
    local makeBlob = string.blob or function(length) return string.rep('\0', math.max(41, length)) end
    local buffer = makeBlob(256 * 4)
    local maximum = math.max(1, math.floor(tonumber(ConfigTarget.PointScanLimit) or 16))
    local found = Citizen.InvokeNative(
        0x345EC3B7EBDE1CB5,
        GetEntityCoords(PlayerPedId()),
        tonumber(ConfigTarget.PointSearchDistance) or 0.5,
        buffer,
        maximum
    )
    if not found or found < 1 then return {} end

    local result = {}
    for index = 1, math.min(found, maximum) do
        local unpacked, pointId = pcall(string.unpack, '<i4', buffer, 9 + ((index - 1) * 8))
        if unpacked and pointId and pointId ~= 0 then
            local attached = Citizen.InvokeNative(0x7467165EE97D3C68, pointId)
            if not attached or attached == 0 or attached == selectedObject then
                local coords = Citizen.InvokeNative(0xA8452DD321607029, pointId, true, Citizen.ResultAsVector())
                if coords then
                    local heading = Citizen.InvokeNative(
                        0xB93EA7184BAA85C3,
                        pointId,
                        true,
                        Citizen.ResultAsFloat()
                    )
                    heading = tonumber(heading) or GetEntityHeading(PlayerPedId())
                    local offset = withoutObjectOffset(withoutPoseOffset(
                        pointToObjectOffset(coords, heading), selectedScenario))
                    if offset then
                        result[#result + 1] = {
                            coords = { x = coords.x, y = coords.y, z = coords.z },
                            heading = heading,
                            offset = offset,
                        }
                    end
                end
            end
        end
    end
    return result
end

local function collectPointOffsets()
    local added = false
    for _, candidate in ipairs(scanPointOffsetsAtPlayer()) do
        local duplicate = false
        for _, saved in ipairs(currentLibrary.offsets or {}) do
            if sameOffset(saved, candidate.offset) then duplicate = true break end
        end
        if not duplicate then
            for _, discovered in ipairs(availablePointOffsets) do
                if sameOffset(discovered.offset, candidate.offset) then duplicate = true break end
            end
        end
        if not duplicate then
            availablePointOffsets[#availablePointOffsets + 1] = candidate
            added = true
        end
    end
    if added and fineTuneActive then
        SendNUIMessage({ action = 'editorPoints', points = availablePointOffsets })
    end
end

local function startPointScanner()
    pointScanSession = pointScanSession + 1
    local session = pointScanSession
    local previous = GetEntityCoords(PlayerPedId())
    CreateThread(function()
        while fineTuneActive and session == pointScanSession do
            Wait(math.max(100, math.floor(tonumber(ConfigTarget.PointScanInterval) or 350)))
            if not fineTuneActive or session ~= pointScanSession then break end
            local coords = GetEntityCoords(PlayerPedId())
            local dx, dy, dz = coords.x - previous.x, coords.y - previous.y, coords.z - previous.z
            local threshold = math.max(0.01, tonumber(ConfigTarget.PointScanMoveThreshold) or 0.1)
            if (dx * dx) + (dy * dy) + (dz * dz) >= threshold * threshold then
                previous = coords
                collectPointOffsets()
            end
        end
    end)
end

local function scenarioTransform(entity, offset)
    if not objectExists(entity) then return nil end
    local coords = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    local heading = (GetEntityHeading(entity) + offset.heading) % 360.0
    return coords, heading
end

local function startScenarioAtTransform(scenarioName, coords, heading)
    if not coords then return false end
    local ped = PlayerPedId()
    if posePropTracking and not posePropCleanupPending then
        deleteTrackedPoseProps(ped)
    else
        beginPosePropTracking(ped)
    end
    ClearPedTasksImmediately(ped)
    Wait(50)
    Citizen.InvokeNative(
        0x4D1F61FC34AF3CD1,
        ped,
        GetHashKey(scenarioName),
        coords.x,
        coords.y,
        coords.z,
        heading,
        -1,
        false,
        true
    )
    return true
end

local function startScenarioInPlace(scenarioName, coords, heading)
    -- Keep the existing editor routing, but use TASK_START_SCENARIO_AT_POSITION
    -- for every scenario. When no transform is supplied, anchor it at the ped.
    local ped = PlayerPedId()
    local position = coords or GetEntityCoords(ped)
    return startScenarioAtTransform(
        scenarioName,
        position,
        heading ~= nil and heading or GetEntityHeading(ped)
    )
end

local function startScenario(entity, scenarioName, pointOffset, poseOffsetOverride, objectOffsetOverride, coordOffsetOverride)
    local adjustment = poseOffsetOverride
    if adjustment == nil then adjustment = poseOffsetFor(scenarioName) end
    local itemAdjustment = objectOffsetOverride
    if itemAdjustment == nil then itemAdjustment = currentObjectOffset end
    local coordAdjustment = coordOffsetOverride
    if coordAdjustment == nil then coordAdjustment = coordOffsetFor(pointOffset) end
    if coordAdjustment == false then coordAdjustment = nil end
    local posePoint = combinedOffset(combinedOffset(pointOffset, coordAdjustment), adjustment)
    local coords, heading = scenarioTransform(entity, combinedOffset(itemAdjustment or {}, posePoint))
    return startScenarioAtTransform(scenarioName, coords, heading)
end

local function usePose(groupName, scenarioName, coordNumber)
    coordNumber = tonumber(coordNumber) or 1
    local offset = currentLibrary.offsets[coordNumber]
    local origin = activePose and copyTransform(activePose.origin) or pedTransform(PlayerPedId())
    if not offset or not startScenario(selectedObject, scenarioName, offset) then
        notify('That object has no usable point.', 'error')
        return
    end
    setActivePose({
        entity = selectedObject,
        model = selectedModel,
        group = groupName,
        scenario = scenarioName,
        coordNumber = coordNumber,
        offset = copyOffset(offset),
        pointGroup = currentLibrary.pointGroups[coordNumber] or DEFAULT_POINT_GROUP,
        origin = origin,
    })
    objectMenuVisible = false
    NtMenu.hide(false)
end

local function roundToTenth(value)
    value = tonumber(value) or 0.0
    if value >= 0.0 then return math.floor((value * 10.0) + 0.5) / 10.0 end
    return math.ceil((value * 10.0) - 0.5) / 10.0
end

local function exitPositionBlocked(ped, coords)
    local radius = math.max(0.1, tonumber(ConfigTarget.ExitCollisionRadius) or 0.3)
    local test = StartShapeTestCapsule(
        coords.x,
        coords.y,
        coords.z + radius + 0.05,
        coords.x,
        coords.y,
        coords.z + 1.6,
        radius,
        17, -- World geometry and objects.
        ped,
        7
    )
    for _ = 1, 10 do
        local status, hit = GetShapeTestResult(test)
        if status == 2 then
            if hit == true or hit == 1 then return true, 'capsule collision detected' end
            break
        end
        if status == 0 then break end
        Wait(0)
    end

    local ok, found, safe = pcall(GetSafeCoordForPed, coords.x, coords.y, coords.z, true, 16)
    if ok and found and safe then
        local dx, dy, dz = safe.x - coords.x, safe.y - coords.y, safe.z - coords.z
        local tolerance = math.max(0.1, tonumber(ConfigTarget.ExitSafeCoordTolerance) or 0.75)
        local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        if distance > tolerance then
            return true, ('safe coordinate moved %.3f m (limit %.3f m)'):format(distance, tolerance)
        end
    end
    return false, ok and 'exit position is clear' or 'safe-coordinate native unavailable; capsule is clear'
end

local function resurrectAfterPoseExit(ped, origin, poseCoords)
    origin = copyTransform(origin) or pedTransform(ped)
    poseCoords = copyTransform(poseCoords) or pedTransform(ped)
    local current = pedTransform(ped)
    local originalZ = roundToTenth(origin.z)
    local poseZ = roundToTenth(poseCoords.z)
    local currentZ = roundToTenth(current.z)
    local direction = originalZ > poseZ and 1 or (originalZ < poseZ and -1 or 0)
    local destination
    local exitReason

    leaveDebug(
        'checking after wait: originZ=%.4f (%.1f) poseZ=%.4f (%.1f) currentZ=%.4f (%.1f)',
        origin.z, originalZ, poseCoords.z, poseZ, current.z, currentZ
    )

    if currentZ == originalZ then
        destination = current
        exitReason = 'Z returned to the original tenth'
    else
        destination = copyTransform(origin)
        local crossedOriginal = (direction > 0 and current.z > origin.z + 0.05)
            or (direction < 0 and current.z < origin.z - 0.05)
        exitReason = crossedOriginal and 'Z crossed the original level' or 'Z did not return after wait'
        leaveDebug('FAIL: %s; falling back to the original position', exitReason)
    end

    local blocked, collisionReason = exitPositionBlocked(ped, destination)
    if blocked then
        leaveDebug('FAIL: selected exit rejected (%s); falling back to the original position', collisionReason)
        destination = copyTransform(origin)
        exitReason = exitReason .. ' + collision fallback'
    else
        leaveDebug('selected exit accepted: %s', collisionReason)
    end

    local health = GetEntityHealth(ped)
    leaveDebug(
        'resurrecting at (%.4f, %.4f, %.4f, %.2f), health=%d, reason=%s',
        destination.x, destination.y, destination.z, destination.heading, health, exitReason
    )
    NetworkResurrectLocalPlayer(
        destination.x,
        destination.y,
        destination.z,
        destination.heading,
        false,
        false
    )
    SetEntityHealth(PlayerPedId(), health)
    leaveDebug('resurrection complete: ped=%d', PlayerPedId())
end

local function leavePose()
    local ped = PlayerPedId()
    local origin = activePose and copyTransform(activePose.origin) or pedTransform(ped)
    local poseCoords = pedTransform(ped)
    leaveDebug(
        'requested: scenario=%s origin=(%.4f, %.4f, %.4f, %.2f) current=(%.4f, %.4f, %.4f, %.2f)',
        activePose and tostring(activePose.scenario) or 'unknown',
        origin.x, origin.y, origin.z, origin.heading,
        poseCoords.x, poseCoords.y, poseCoords.z, poseCoords.heading
    )
    finishPosePropCleanup(ped)
    --SetEntityCoords(ped, origin.x, origin.y, origin.z, false, false, false, false)
    --SetEntityHeading(ped, origin.heading)
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)
    NetworkResurrectLocalPlayer(
        origin.x,
        origin.y,
        origin.z,
        origin.heading,
        false,
        false
    )
    setActivePose(nil)
end

local function refreshLibrary()
    local response = lib.callback.await('nt_actions:server:getObjectLibrary', false, selectedModel) or {}
    local library = type(response.library) == 'table' and response.library or {}
    local offsets = type(library.offsets) == 'table' and library.offsets or {}
    local savedPoses = type(library.poses) == 'table' and library.poses or {}
    local pointGroups = type(library.pointGroups) == 'table' and library.pointGroups or {}
    local pointGroupNames = type(library.pointGroupNames) == 'table' and library.pointGroupNames or {}
    local posePointGroups = type(library.posePointGroups) == 'table' and library.posePointGroups or {}
    local records = {}
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for groupName, poses in pairs(type(savedPoses[visibility]) == 'table' and savedPoses[visibility] or {}) do
            for _, value in ipairs(type(poses) == 'table' and poses or {}) do
                local scenarioName = value.scenario or value[1]
                if configuredEntry(groupName, scenarioName) then
                    records[#records + 1] = {
                        group = groupName,
                        scenario = scenarioName,
                        visibility = visibility,
                        pointGroup = posePointGroups[scenarioName] or DEFAULT_POINT_GROUP,
                    }
                end
            end
        end
    end
    table.sort(records, function(a, b)
        if a.visibility ~= b.visibility then return a.visibility == 'show' end
        if a.group ~= b.group then return a.group:lower() < b.group:lower() end
        if a.scenario ~= b.scenario then return a.scenario:lower() < b.scenario:lower() end
        return false
    end)
    currentLibrary = { records = records, offsets = offsets, pointGroups = pointGroups, pointGroupNames = pointGroupNames }
    currentPreset = type(response.preset) == 'string' and response.preset or nil
    currentObjectOffset = type(response.objectOffset) == 'table' and copyOffset(response.objectOffset) or nil
    currentCoordOffsets = type(response.coordOffsets) == 'table' and response.coordOffsets or {}
    poseOffsets = type(response.poseOffsets) == 'table' and response.poseOffsets or poseOffsets
    canEditPoseOffsets = response.canEditPoseOffsets == true
    if activePose and activePose.model == selectedModel then
        local coordNumber
        for index, offset in ipairs(offsets) do
            if sameOffset(offset, activePose.offset) then coordNumber = index break end
        end
        activePose.coordNumber = coordNumber
    end
    canDeleteGroups = response.canDelete == true
    if not canDeleteGroups and not canEditPoseOffsets then modModeActive = false end
end

local function cameraTargetCoords()
    local coords = GetEntityCoords(PlayerPedId())
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z + (tonumber(ConfigTarget.CameraLookAtHeight) or 0.75),
    }
end

local function captureCameraOrbit()
    if not fineTuneCamera or not DoesCamExist(fineTuneCamera) then return end
    local cameraCoords = GetCamCoord(fineTuneCamera)
    local target = cameraTargetCoords()
    local dx, dy, dz = cameraCoords.x - target.x, cameraCoords.y - target.y, cameraCoords.z - target.z
    orbitRadius = math.max(0.5, math.sqrt(dx * dx + dy * dy + dz * dz))
    orbitYaw = math.atan(dy, dx)
    orbitPitch = math.asin(math.max(-1.0, math.min(1.0, dz / orbitRadius)))
end

local function positionOrbitCamera(camera, target)
    local horizontalRadius = orbitRadius * math.cos(orbitPitch)
    SetCamCoord(
        camera,
        target.x + math.cos(orbitYaw) * horizontalRadius,
        target.y + math.sin(orbitYaw) * horizontalRadius,
        target.z + math.sin(orbitPitch) * orbitRadius
    )
    PointCamAtCoord(camera, target.x, target.y, target.z)
end

local function stopFineTuneCamera(immediate)
    if not fineTuneCamera then return end
    local camera = fineTuneCamera
    fineTuneCamera = nil
    local transition = immediate and 0 or (tonumber(ConfigTarget.CameraTransition) or 250)
    RenderScriptCams(false, not immediate, transition, true, true)
    CreateThread(function()
        if transition > 0 then Wait(transition) end
        if DoesCamExist(camera) then DestroyCam(camera, false) end
    end)
end

local function startFineTuneCamera(anchor, gameplayCameraCoords, scenarioHeading)
    stopFineTuneCamera(true)
    local target = cameraTargetCoords()
    local lookZ = anchor.z + (tonumber(ConfigTarget.CameraLookAtHeight) or 0.75)
    local horizontal = math.sqrt(((gameplayCameraCoords.x - anchor.x) ^ 2) + ((gameplayCameraCoords.y - anchor.y) ^ 2))
    local currentHeight = gameplayCameraCoords.z - lookZ
    local minimumPitch = math.rad(tonumber(ConfigTarget.CameraMinPitch) or -60.0)
    local maximumPitch = math.rad(tonumber(ConfigTarget.CameraMaxPitch) or 75.0)

    local zoomMin = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local zoomMax = math.max(zoomMin, tonumber(ConfigTarget.CameraZoomMax) or 8.0)
    orbitRadius = math.max(zoomMin, math.min(zoomMax, tonumber(editorSettings.DefaultCameraZoom) or 3.0))
    orbitYaw = math.rad((scenarioHeading or 0.0) - 90.0)
    orbitPitch = math.max(minimumPitch, math.min(maximumPitch, math.atan(currentHeight, horizontal)))

    fineTuneCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(fineTuneCamera, tonumber(ConfigTarget.CameraFov) or 50.0)
    positionOrbitCamera(fineTuneCamera, target)
    SetCamActive(fineTuneCamera, true)
    RenderScriptCams(true, true, tonumber(ConfigTarget.CameraTransition) or 250, true, true)
    local camera = fineTuneCamera

    CreateThread(function()
        while fineTuneCamera == camera and DoesCamExist(camera) do
            target = cameraTargetCoords()
            if cameraLookActive then
                local sensitivity = math.rad(tonumber(ConfigTarget.CameraOrbitSensitivity) or 4.0)
                local lookX = GetControlNormal(0, ConfigTarget.CameraLookX or 0xA987235F)
                local lookY = GetControlNormal(0, ConfigTarget.CameraLookY or 0xD2047988)
                orbitYaw = orbitYaw - (lookX * sensitivity)
                orbitPitch = math.max(minimumPitch, math.min(maximumPitch, orbitPitch + (lookY * sensitivity)))
                positionOrbitCamera(camera, target)
            end
            PointCamAtCoord(camera, target.x, target.y, target.z)
            Wait(0)
        end
    end)
end

local function closeFineTune()
    fineTuneActive = false
    pointScanSession = pointScanSession + 1
    editorOpening = false
    editorScenarioInPlace = false
    editorMoveSetActive = false
    poseMenuBlockedUntil = 0
    cameraLookActive = false
    stopFineTuneCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function previewEditorScenario()
    if editorMode == 'poseOffset' then
        return startScenario(selectedObject, selectedScenario, editorPointOffset, currentOffset)
    end
    if editorMode == 'objectOffset' then
        return startScenario(selectedObject, selectedScenario, editorPointOffset, nil, currentOffset)
    end
    if editorMode == 'coordOffset' then
        local point = combinedOffset(editorPointOffset, currentOffset)
        local posePoint = combinedOffset(point, poseOffsetFor(selectedScenario))
        local coords, heading = scenarioTransform(selectedObject, combinedOffset(currentObjectOffset or {}, posePoint))
        return startScenarioAtTransform(selectedScenario, coords, heading)
    end
    if editorScenarioInPlace then
        local posePoint = combinedOffset(currentOffset, poseOffsetFor(selectedScenario))
        local offset = combinedOffset(currentObjectOffset or {}, posePoint)
        local coords, heading = scenarioTransform(selectedObject, offset)
        if not coords then return false end
        return startScenarioInPlace(selectedScenario, coords, heading)
    end
    return startScenario(selectedObject, selectedScenario, currentOffset)
end

local function beginEditor(groupName, scenarioName, mode, coordNumber)
    if not objectExists(selectedObject) then
        notify('That object is no longer available.', 'error')
        return
    end
    if mode == 'add' and not ensurePresetName() then return end

    if mode == 'add' then
        poseMenuBlockedUntil = GetGameTimer() + math.max(
            0,
            math.floor(tonumber(ConfigTarget.AddPoseMenuDelay) or 5000)
        )
    end

    objectMenuVisible = false
    selectedGroup = groupName
    selectedScenario = scenarioName
    editorMode = mode
    editorCoordNumber = tonumber(coordNumber)
    editorPreviousPose = activePose and {
        entity = activePose.entity,
        model = activePose.model,
        group = activePose.group,
        scenario = activePose.scenario,
        coordNumber = activePose.coordNumber,
        offset = copyOffset(activePose.offset),
        origin = copyTransform(activePose.origin),
    } or nil
    editorOrigin = pedTransform(PlayerPedId())
    local groupConfig = ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[groupName]
    -- objectOffset defaults to true so custom/older groups retain the existing setup behavior.
    local useObjectOffset = not groupConfig or groupConfig.objectOffset ~= false
    local startInPlace = mode == 'add' and not useObjectOffset
    editorScenarioInPlace = startInPlace
    local savedOffset = mode == 'modify' and editorCoordNumber and currentLibrary.offsets[editorCoordNumber] or nil
    local activeObjectOffset = (mode == 'add' or mode == 'poseOffset' or mode == 'objectOffset' or mode == 'coordOffset')
        and activePose
        and activePose.entity == selectedObject
        and activePose.offset
        or nil
    local selectedPointOffset = (mode == 'add' or mode == 'poseOffset' or mode == 'objectOffset' or mode == 'coordOffset')
        and currentLibrary.offsets[editorCoordNumber or selectedMenuCoord] or nil
    editorPointOffset = copyOffset(activeObjectOffset or selectedPointOffset)
    currentOffset = mode == 'poseOffset'
        and copyOffset(poseOffsetFor(scenarioName) or {})
        or mode == 'objectOffset'
            and copyOffset(currentObjectOffset or {})
            or mode == 'coordOffset'
                and copyOffset(coordOffsetFor(selectedPointOffset) or {})
            or copyOffset(savedOffset or activeObjectOffset or selectedPointOffset)
    availablePointOffsets = {}
    editorOpening = true

    NtMenu.hide(false)
    local manualObjectOffset = mode == 'objectOffset'
    local started = manualObjectOffset or (startInPlace
        and startScenarioInPlace(selectedScenario)
        or previewEditorScenario())
    if not started then
        editorOpening = false
        return
    end

    if mode ~= 'poseOffset' and mode ~= 'objectOffset' and mode ~= 'coordOffset' then
        Wait(math.max(0, math.floor(tonumber(ConfigTarget.PointSearchDelay) or 3000)))
        if startInPlace then
            local settled = pedTransform(PlayerPedId())
            currentOffset = withoutObjectOffset(withoutPoseOffset(
                pointToObjectOffset(settled, settled.heading), scenarioName))
        end
    end
    if not objectExists(selectedObject) then
        editorOpening = false
        ClearPedTasksImmediately(PlayerPedId())
        notify('That object is no longer available.', 'error')
        return
    end
    if mode ~= 'poseOffset' and mode ~= 'objectOffset' and mode ~= 'coordOffset' then collectPointOffsets() end

    local gameplayCameraCoords = GetGameplayCamCoord()
    local objectCoords = GetEntityCoords(selectedObject)
    local cameraOffset = mode == 'poseOffset'
        and combinedOffset(currentObjectOffset or {}, combinedOffset(editorPointOffset, currentOffset))
        or mode == 'objectOffset'
            and combinedOffset(currentOffset, combinedOffset(editorPointOffset, poseOffsetFor(scenarioName)))
            or mode == 'coordOffset'
                and combinedOffset(currentObjectOffset or {}, combinedOffset(combinedOffset(editorPointOffset, currentOffset), poseOffsetFor(scenarioName)))
            or combinedOffset(currentObjectOffset or {}, currentOffset)
    local _, heading = scenarioTransform(selectedObject, cameraOffset)
    if not manualObjectOffset then startFineTuneCamera(objectCoords, gameplayCameraCoords, heading) end
    fineTuneActive = true
    editorMoveSetActive = not manualObjectOffset
    editorOpening = false
    if mode ~= 'poseOffset' and mode ~= 'objectOffset' and mode ~= 'coordOffset' then startPointScanner() end
    local cameraZoomMin = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local cameraZoomMax = math.max(cameraZoomMin, tonumber(ConfigTarget.CameraZoomMax) or 8.0, orbitRadius)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        editorTitle = mode == 'poseOffset'
            and (editorSettings.PoseOffsetTitle or 'Adjust global pose offset')
            or mode == 'objectOffset'
                and (editorSettings.ObjectOffsetTitle or 'Adjust object offset')
                or mode == 'coordOffset'
                    and (editorSettings.CoordOffsetTitle or 'Adjust coordinate offset')
                or (mode == 'modify' and (editorSettings.ModifyTitle or 'Modify point')
                or (editorSettings.AddTitle or 'Add pose')),
        scale = NtMenu.getScale(),
        points = availablePointOffsets,
        step = defaultEditorStep(),
        stepMin = ConfigTarget.FineTuneStepMin,
        stepMax = ConfigTarget.FineTuneStepMax,
        sliderStep = ConfigTarget.FineTuneSliderStep,
        rotationMultiplier = ConfigTarget.RotationStepMultiplier,
        cameraDistance = orbitRadius,
        cameraZoomMin = cameraZoomMin,
        cameraZoomMax = cameraZoomMax,
        cameraZoomStep = ConfigTarget.CameraZoomStep,
        offset = currentOffset,
        coordinates = (mode == 'poseOffset' or mode == 'objectOffset' or mode == 'coordOffset') and {} or currentLibrary.offsets,
        selectedCoordinate = mode ~= 'poseOffset' and mode ~= 'objectOffset' and mode ~= 'coordOffset'
            and not (mode == 'add' and not useObjectOffset)
            and (editorCoordNumber or selectedMenuCoord)
            or nil,
        showSeparatePoint = mode == 'modify',
        manualOffset = manualObjectOffset,
        movementLocked = manualObjectOffset,
        canMoveSet = manualObjectOffset and selectedScenario ~= nil and editorPointOffset ~= nil,
        playerCoordinates = manualObjectOffset and editorOrigin or nil,
        objectCoordinates = manualObjectOffset and {
            x = objectCoords.x, y = objectCoords.y, z = objectCoords.z,
        } or nil,
    })
end

local function openAddPoseMenu(groupName)
    objectMenuVisible = false
    local options = {}
    for _, entry in ipairs(groupPoses(groupName)) do
        local scenarioName = entry[1]
        if scenarioName and compatible(entry) then
            local existing = 0
            for _, record in ipairs(currentLibrary.records or {}) do
                if record.group == groupName and record.scenario == scenarioName then existing = existing + 1 end
            end
            options[#options + 1] = {
                label = poseLabel(groupName, entry),
                description = existing > 0 and ('%s - %d saved'):format(groupName, existing) or groupName,
                args = { scenario = scenarioName },
            }
        end
    end
    if #options == 0 then options[1] = { label = configuredText('AllGroupPosesAdded', 'All poses in this group are already added'), disabled = true } end

    NtMenu.open(groupName, options, function(_, args)
        beginEditor(groupName, args.scenario, 'add')
    end)
end

local function openAddGroupMenu()
    objectMenuVisible = false
    local options = {}
    for _, groupName in ipairs(orderedGroups()) do
        local available = 0
        for _, entry in ipairs(groupPoses(groupName)) do
            if entry[1] and compatible(entry) then available = available + 1 end
        end
        if available > 0 then
            options[#options + 1] = {
                label = groupName,
                description = ('%d pose%s available'):format(available, available == 1 and '' or 's'),
                args = { group = groupName },
            }
        end
    end
    if #options == 0 then options[1] = { label = configuredText('AllGroupsAdded', 'All poses are already added'), disabled = true } end

    NtMenu.open(configuredText('AddGroupTitle', 'Add Pose'), options, function(_, args)
        openAddPoseMenu(args.group)
    end)
end

local function hiddenPoseCount()
    local count = 0
    local selectedPointGroup = currentLibrary.pointGroups[selectedMenuCoord] or DEFAULT_POINT_GROUP
    for _, record in ipairs(currentLibrary.records or {}) do
        if record.visibility == 'noshow' and record.pointGroup == selectedPointGroup then count = count + 1 end
    end
    return count
end

local function openUndoMenu()
    if not canDeleteGroups then return end
    objectMenuVisible = false
    local selectedPointGroup = currentLibrary.pointGroups[selectedMenuCoord] or DEFAULT_POINT_GROUP
    local options = {}
    for _, record in ipairs(currentLibrary.records or {}) do
        if record.visibility == 'noshow' and record.pointGroup == selectedPointGroup then
            local entry = configuredEntry(record.group, record.scenario)
            local label = poseLabel(record.group, entry)
            options[#options + 1] = {
                label = label,
                description = record.group,
                disabled = true,
                restorable = true,
                deletable = true,
                args = {
                    action = 'hiddenPose',
                    group = record.group,
                    scenario = record.scenario,
                    poseLabel = label,
                },
            }
        end
    end
    if #options == 0 then
        options[1] = { label = configuredText('NoHiddenPoses', 'No hidden poses'), disabled = true }
    end

    NtMenu.open(configuredText('UndoTitle', 'Hidden Poses'), options, nil, nil, {
        onRestore = function(_, args)
            objectMenuVisible = false
            local restored = lib.callback.await(
                'nt_actions:server:restoreObjectPose',
                false,
                selectedModel,
                args.group,
                args.scenario,
                args.number or 0
            )
            if not restored then
                notify('You do not have permission to restore that pose.', 'error')
                return
            end
            notify(('%s was restored to this object.'):format(args.poseLabel or 'Pose'), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
        onDelete = function(_, args)
            local deleted = lib.callback.await(
                'nt_actions:server:deleteHiddenObjectPose', false,
                selectedModel, args.group, args.scenario, args.number or 0
            )
            if not deleted then notify('That hidden pose could not be deleted.', 'error') return end
            notify(('%s was permanently deleted.'):format(args.poseLabel or 'Pose'), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
            openUndoMenu()
        end,
    })
end

local function savedPoseVisibility(groupName, scenarioName)
    for _, record in ipairs(currentLibrary.records or {}) do
        if record.group == groupName and record.scenario == scenarioName then return record.visibility end
    end
end

local function openMultiAddGroupMenu(groupName)
    local selected = {}
    local options = {}
    local footer = {
        { label = 'Add Selected', disabled = true, args = { action = 'addSelected' } },
    }

    for _, entry in ipairs(groupPoses(groupName)) do
        local scenarioName = entry[1]
        if scenarioName then
            local visibility = savedPoseVisibility(groupName, scenarioName)
            options[#options + 1] = {
                label = poseLabel(groupName, entry),
                description = visibility == 'show' and 'Already published.'
                    or visibility == 'noshow' and 'Hidden by a moderator.'
                    or groupName,
                disabled = visibility ~= nil,
                checkable = visibility == nil,
                checked = false,
                args = { group = groupName, scenario = scenarioName },
            }
        end
    end

    local function updateSelectionState()
        local count = 0
        for _ in pairs(selected) do count = count + 1 end
        footer[1].disabled = count == 0
        footer[1].label = count > 0 and ('Add Selected (%d)'):format(count) or 'Add Selected'
    end

    NtMenu.open(('Multi Add - %s'):format(groupName), options, function() end, nil, {
        footerActions = footer,
        onCheck = function(_, args, value)
            selected[args.scenario] = value == true
                and { group = args.group, scenario = args.scenario }
                or nil
            updateSelectionState()
            NtMenu.refreshFooter()
        end,
        onFooter = function(_, args)
            if args.action ~= 'addSelected' then return end
            local request = {}
            for _, selection in pairs(selected) do request[#request + 1] = selection end
            table.sort(request, function(a, b)
                if a.group ~= b.group then return a.group < b.group end
                return a.scenario < b.scenario
            end)
            local presetName = ensurePresetName()
            if not presetName then return end
            local result = lib.callback.await('nt_actions:server:bulkAddObjectPoses', false, selectedModel, request,
                currentLibrary.pointGroups[selectedMenuCoord] or DEFAULT_POINT_GROUP, presetName)
            if type(result) ~= 'table' then
                notify('The selected poses could not be added.', 'error')
                return
            end
            notify(('%d poses added; %d skipped.'):format(result.added or 0, result.skipped or 0), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
    })
end

local function openMultiAddMenu()
    local options = {}
    for _, groupName in ipairs(orderedGroups()) do
        local available = 0
        for _, entry in ipairs(groupPoses(groupName)) do
            if entry[1] and not savedPoseVisibility(groupName, entry[1]) then available = available + 1 end
        end
        options[#options + 1] = {
            label = groupName,
            description = available > 0
                and ('%d pose%s available.'):format(available, available == 1 and '' or 's')
                or 'Every pose in this group is already published or hidden.',
            disabled = available == 0,
            args = { group = groupName },
        }
    end
    if #options == 0 then
        options[1] = { label = 'No pose groups configured', disabled = true }
    end

    NtMenu.open('Multi Add - Select Group', options, function(_, args)
        openMultiAddGroupMenu(args.group)
    end)
end

local function presetPayload(entry, activeName)
    local library = type(entry.library) == 'table' and entry.library or {}
    local points, poses = {}, {}
    local groupCounts = {}
    for index, offset in ipairs(type(library.offsets) == 'table' and library.offsets or {}) do
        local pointGroup = type(library.pointGroups) == 'table' and library.pointGroups[index] or DEFAULT_POINT_GROUP
        groupCounts[pointGroup] = (groupCounts[pointGroup] or 0) + 1
        points[#points + 1] = {
            label = ('%s - Point %d (%.3f, %.3f, %.3f, %.1f)'):format(pointGroup, groupCounts[pointGroup],
                tonumber(offset.x) or 0.0, tonumber(offset.y) or 0.0, tonumber(offset.z) or 0.0, tonumber(offset.heading) or 0.0),
            offset = copyOffset(offset), pointGroup = pointGroup,
        }
    end
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for groupName, records in pairs(type(library.poses) == 'table' and library.poses[visibility] or {}) do
            for _, record in ipairs(records) do
                local entryConfig = configuredEntry(groupName, record.scenario)
                if entryConfig then
                    poses[#poses + 1] = {
                        group = groupName, scenario = record.scenario, visibility = visibility,
                        pointGroup = type(library.posePointGroups) == 'table' and library.posePointGroups[record.scenario] or DEFAULT_POINT_GROUP,
                        label = poseLabel(groupName, entryConfig),
                    }
                end
            end
        end
    end
    table.sort(poses, function(a, b) return a.label:lower() < b.label:lower() end)
    return { name = entry.name, active = entry.name == activeName, points = points, poses = poses }
end

local function openPresetEditor()
    if not canDeleteGroups or not objectExists(selectedObject) then return end
    local response = lib.callback.await('nt_actions:server:getPresets', false, selectedModel)
    if type(response) ~= 'table' then notify('Presets could not be loaded.', 'error') return end
    presetCache = {}
    local payload = {}
    for _, entry in ipairs(type(response.presets) == 'table' and response.presets or {}) do
        local preset = presetPayload(entry, response.active)
        presetCache[preset.name] = preset
        payload[#payload + 1] = preset
    end
    presetEditorActive = true
    objectMenuVisible = false
    NtMenu.hide(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'presetOpen', presets = payload })
end

local function closePresetEditor(reopenMenu)
    if not presetEditorActive then return end
    presetEditorActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'presetClose' })
    if activePose and objectExists(activePose.entity) then
        startScenario(activePose.entity, activePose.scenario, activePose.offset)
    else
        ClearPedTasks(PlayerPedId())
        if posePropTracking then deleteTrackedPoseProps(PlayerPedId()) end
    end
    if reopenMenu and objectExists(selectedObject) then openObjectMenu(selectedObject, true) end
end
local function openGroupEditor()
    if not canDeleteGroups or not objectExists(selectedObject) then return end
    local grouped, names = {}, {}
    local function ensureGroup(name)
        name = type(name) == 'string' and name ~= '' and name or DEFAULT_POINT_GROUP
        if not grouped[name] then
            grouped[name] = { name = name, points = {}, poses = {} }
            names[#names + 1] = name
        end
        return grouped[name]
    end

    for name in pairs(currentLibrary.pointGroupNames or {}) do ensureGroup(name) end

    local localPointNumbers = {}
    for offsetIndex, offset in ipairs(currentLibrary.offsets) do
        local pointGroup = currentLibrary.pointGroups[offsetIndex] or DEFAULT_POINT_GROUP
        localPointNumbers[pointGroup] = (localPointNumbers[pointGroup] or 0) + 1
        ensureGroup(pointGroup).points[#ensureGroup(pointGroup).points + 1] = {
            index = offsetIndex,
            label = ('Point %d'):format(localPointNumbers[pointGroup]),
            title = ('x %.3f, y %.3f, z %.3f, heading %.1f'):format(
                tonumber(offset.x) or 0.0, tonumber(offset.y) or 0.0,
                tonumber(offset.z) or 0.0, tonumber(offset.heading) or 0.0),
        }
    end
    for _, record in ipairs(currentLibrary.records or {}) do
        local pointGroup = record.pointGroup or DEFAULT_POINT_GROUP
        local entry = configuredEntry(record.group, record.scenario)
        ensureGroup(pointGroup).poses[#ensureGroup(pointGroup).poses + 1] = {
            group = record.group,
            scenario = record.scenario,
            label = entry and poseLabel(record.group, entry) or prettyWords(record.scenario),
            visibility = record.visibility,
        }
    end
    if #names == 0 then ensureGroup(DEFAULT_POINT_GROUP) end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    local groups = {}
    for _, name in ipairs(names) do
        local group = grouped[name]
        table.sort(group.poses, function(a, b) return a.label:lower() < b.label:lower() end)
        groups[#groups + 1] = group
    end

    groupEditorActive = true
    objectMenuVisible = false
    NtMenu.hide(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'groupEditorOpen', groups = groups })
end

local function closeGroupEditor(reopenMenu)
    if not groupEditorActive then return end
    groupEditorActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'groupEditorClose' })
    if reopenMenu and objectExists(selectedObject) then openObjectMenu(selectedObject, true) end
end
openObjectMenu = function(entity, preserveSelectedPoint)
    if fineTuneActive or not targetableObject(entity) then return end
    local objectChanged = selectedObject ~= entity
    if objectChanged then
        modModeActive = false
        selectedMenuCoord = 1
    end
    selectedObject = entity
    selectedModel = GetEntityModel(entity)
    refreshLibrary()
    if not preserveSelectedPoint and activePose and activePose.entity == selectedObject and activePose.coordNumber then
        selectedMenuCoord = activePose.coordNumber
    elseif not preserveSelectedPoint and not inPose then
        selectedMenuCoord = 1
    end
    if #currentLibrary.offsets > 0 then
        selectedMenuCoord = math.max(1, math.min(#currentLibrary.offsets, tonumber(selectedMenuCoord) or 1))
    else
        selectedMenuCoord = 1
    end
    objectMenuVisible = true

    local selectedPointGroup = currentLibrary.pointGroups[selectedMenuCoord] or DEFAULT_POINT_GROUP
    local options = {}
    for _, record in ipairs(currentLibrary.records or {}) do
        local entry = configuredEntry(record.group, record.scenario)
        if record.visibility == 'show' and record.pointGroup == selectedPointGroup and entry and compatible(entry) then
            local label = poseLabel(record.group, entry)
            options[#options + 1] = {
                label = label,
                description = record.group,
                deletable = canDeleteGroups and modModeActive,
                args = {
                    action = 'pose', group = record.group, scenario = record.scenario, poseLabel = label,
                },
            }
        end
    end
    if #options == 0 then
        options[1] = { label = configuredText('Empty', 'No poses added to this object'), disabled = true }
    end

    local isActiveObject = activePose and activePose.entity == selectedObject
    local moderatorEditing = canDeleteGroups and modModeActive
    local poseOffsetEditing = canEditPoseOffsets and modModeActive
    local footer = {}
    if moderatorEditing then
        -- Three-column management rows: primary actions, then configuration actions.
        footer[#footer + 1] = { label = configuredText('AddPose', 'Add Pose'), args = { action = 'add' } }
        if isActiveObject then
            footer[#footer + 1] = {
                label = configuredText('Modify', 'Modify'),
                disabled = not activePose.coordNumber,
                args = { action = 'modify' },
            }
        end
        footer[#footer + 1] = { label = 'Multi Add', args = { action = 'multiAdd' } }
        if isActiveObject and poseOffsetEditing then
            footer[#footer + 1] = {
                label = configuredText('PoseOffset', 'Pose Offset'),
                disabled = not activePose.coordNumber,
                args = { action = 'poseOffset' },
            }
        end
        footer[#footer + 1] = {
            label = 'Object Offset',
            disabled = not currentPreset or not isActiveObject or not activePose.coordNumber,
            args = { action = 'objectOffset' },
        }
        footer[#footer + 1] = {
            label = 'Coord Offset',
            disabled = not currentPreset or not isActiveObject or not activePose.coordNumber,
            args = { action = 'coordOffset' },
        }
        footer[#footer + 1] = { label = 'Group Edit', args = { action = 'groupEdit' } }
        footer[#footer + 1] = {
            label = currentPreset and 'Presets' or 'Add Preset',
            args = { action = 'presets' },
        }

        footer[#footer + 1] = {
            label = configuredText('Undo', 'Undo'), disabled = hiddenPoseCount() == 0,
            args = { action = 'undo' },
        }
        -- Leave/Exit actions span the entire bottom row.
        if isActiveObject or inPose then
            footer[#footer + 1] = { label = configuredText('Leave', 'Leave Pose'), wide = true, args = { action = 'leave' } }
        end
        if inPose and not isActiveObject then
            footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), wide = true, args = { action = 'exit' } }
        elseif not inPose then
            footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), wide = true, args = { action = 'exit' } }
        end
    else
        if isActiveObject then
            if poseOffsetEditing then
                footer[#footer + 1] = {
                    label = configuredText('PoseOffset', 'Pose Offset'),
                    disabled = not activePose.coordNumber,
                    args = { action = 'poseOffset' },
                }
            end
            footer[#footer + 1] = { label = configuredText('Leave', 'Leave Pose'), wide = true, args = { action = 'leave' } }
        elseif inPose then
            footer[#footer + 1] = { label = configuredText('Leave', 'Leave Pose'), wide = true, args = { action = 'leave' } }
            footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), wide = true, args = { action = 'exit' } }
        else
            footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), wide = true, args = { action = 'exit' } }
        end
    end
    NtMenu.open(configuredText('ObjectTitle', 'Object Poses'), options, function(_, args)
        if args.action == 'pose' then usePose(args.group, args.scenario, selectedMenuCoord) end
    end, function()
        objectMenuVisible = false
    end, {
        footerActions = footer,
        showMod = canDeleteGroups or canEditPoseOffsets,
        modActive = modModeActive,
        onMod = function()
            modModeActive = not modModeActive
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
        onFooter = function(_, args)
            if args.action == 'add' then
                openAddGroupMenu()
            elseif args.action == 'modify' and activePose and activePose.coordNumber then
                beginEditor(activePose.group, activePose.scenario, 'modify', activePose.coordNumber)
            elseif args.action == 'poseOffset' and activePose and activePose.coordNumber and canEditPoseOffsets then
                beginEditor(activePose.group, activePose.scenario, 'poseOffset', activePose.coordNumber)
            elseif args.action == 'objectOffset' and canDeleteGroups and currentPreset
                and activePose and activePose.entity == selectedObject and activePose.coordNumber then
                beginEditor(activePose.group, activePose.scenario, 'objectOffset', activePose.coordNumber)
            elseif args.action == 'coordOffset' and canDeleteGroups and currentPreset
                and activePose and activePose.entity == selectedObject and activePose.coordNumber then
                beginEditor(activePose.group, activePose.scenario, 'coordOffset', activePose.coordNumber)
            elseif args.action == 'leave' then
                leavePose()
                objectMenuVisible = false
                NtMenu.hide(false)
            elseif args.action == 'exit' then
                objectMenuVisible = false
                NtMenu.hide(false)
            elseif args.action == 'undo' then
                openUndoMenu()
            elseif args.action == 'multiAdd' then
                openMultiAddMenu()
            elseif args.action == 'groupEdit' then
                openGroupEditor()
            elseif args.action == 'presets' then
                openPresetEditor()
            end
        end,
        onDelete = function(_, args)
            objectMenuVisible = false
            local removed = lib.callback.await(
                'nt_actions:server:hideObjectPose', false,
                selectedModel, args.group, args.scenario, 0)
            if not removed then
                objectMenuVisible = true
                notify('You do not have permission to remove that pose.', 'error')
                return
            end

            notify(('%s was hidden from this object.'):format(args.poseLabel or 'Pose'), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
        coordinateOptions = (function()
            local result = {}
            local groupCounts = {}
            for coordNumber, offset in ipairs(currentLibrary.offsets) do
                local pointGroup = currentLibrary.pointGroups[coordNumber] or DEFAULT_POINT_GROUP
                groupCounts[pointGroup] = (groupCounts[pointGroup] or 0) + 1
                result[coordNumber] = {
                    label = tostring(groupCounts[pointGroup]),
                    title = ('%s, point %d'):format(pointGroup, groupCounts[pointGroup]),
                    pointGroup = pointGroup,
                    args = { pointGroup = pointGroup },
                    deletable = canDeleteGroups and modModeActive,
                }
            end
            return result
        end)(),
        selectedCoordinate = selectedMenuCoord,
        onCoordinateSelect = function(coordNumber)
            if not currentLibrary.offsets[coordNumber] then return end
            selectedMenuCoord = coordNumber
            NtMenu.hide(false)
            openObjectMenu(selectedObject, true)
        end,
        onCoordinateDelete = function(coordNumber)
            local removed = lib.callback.await('nt_actions:server:deleteObjectPoint', false, selectedModel, coordNumber)
            if not removed then
                notify('That point could not be removed. Objects with poses must retain at least one point.', 'error')
                return
            end
            notify(('Point %d was removed.'):format(coordNumber), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
    })
end

AddEventHandler('nt_actions:client:openCachedPoseList', function()
    if not inPose or not objectExists(cachedPoseObject) then
        notify('The object for the active pose is no longer available.', 'error')
        return
    end
    openObjectMenu(cachedPoseObject)
end)

RegisterNetEvent('nt_actions:client:poseOffsetUpdated', function(scenarioName, offset)
    if type(scenarioName) ~= 'string' then return end
    poseOffsets[scenarioName] = type(offset) == 'table' and copyOffset(offset) or nil
    if activePose and activePose.scenario == scenarioName and objectExists(activePose.entity) and not fineTuneActive then
        startScenario(activePose.entity, activePose.scenario, activePose.offset)
    end
end)

local function refreshTargetAccess()
    local access = lib.callback.await('nt_actions:server:getTargetAccess', false) or {}
    local models = {}
    for _, model in ipairs(type(access.models) == 'table' and access.models or {}) do
        model = tonumber(model)
        if model then models[model] = true end
    end
    cachedTargetModels = models
    canTargetUnregistered = access.canTargetUnregistered == true
end

local function canTargetObject(entity)
    if fineTuneActive or not targetableObject(entity) then return false end
    return canTargetUnregistered or cachedTargetModels[GetEntityModel(entity)] == true
end

RegisterNetEvent('nt_actions:client:objectLibraryUpdated', function(model)
    refreshTargetAccess()
    if objectMenuVisible and selectedModel == model and objectExists(selectedObject) then
        NtMenu.hide(false)
        openObjectMenu(selectedObject)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', refreshTargetAccess)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', refreshTargetAccess)
RegisterNetEvent('RSGCore:Client:SetDuty', refreshTargetAccess)

CreateThread(function()
    Wait(0)
    poseOffsets = lib.callback.await('nt_actions:server:getPoseOffsets', false) or {}
    refreshTargetAccess()
    exports.ox_target:addGlobalObject({
        {
            name = TARGET_OPTION,
            icon = ConfigTarget.TargetIcon,
            label = ConfigTarget.TargetLabel,
            distance = ConfigTarget.TargetDistance,
            canInteract = function(entity)
                return canTargetObject(entity)
            end,
            onSelect = function(data)
                local entity = data and data.entity
                if canTargetObject(entity) then openObjectMenu(entity) end
            end,
        },
    })
end)

-- Duty changes are event-driven above; this fallback supports core versions
-- that do not emit every client job event.
CreateThread(function()
    while true do
        Wait(5000)
        refreshTargetAccess()
    end
end)

RegisterNUICallback('presetClose', function(_, cb)
    closePresetEditor(true)
    cb({ ok = true })
end)

RegisterNUICallback('presetPreview', function(data, cb)
    local preset = presetEditorActive and presetCache[type(data.preset) == 'string' and data.preset or ''] or nil
    local pointIndex = tonumber(data.point)
    local scenarioName = type(data.pose) == 'string' and data.pose or nil
    local point = preset and pointIndex and preset.points[pointIndex] or nil
    local valid = false
    if preset and scenarioName then
        for _, pose in ipairs(preset.poses) do if pose.scenario == scenarioName then valid = true break end end
    end
    local coordOverride = preset and preset.active == true and nil or false
    cb({ ok = valid and point and startScenario(selectedObject, scenarioName, point.offset, nil, nil, coordOverride) == true or false })
end)

RegisterNUICallback('presetApply', function(data, cb)
    local name = type(data.name) == 'string' and data.name or nil
    if not presetEditorActive or not name or not presetCache[name] then cb({ ok = false, error = 'Select a valid preset.' }) return end
    local remove = data.remove == true
    if remove and presetCache[name].active ~= true then
        cb({ ok = false, error = 'That preset is not active on this object.' })
        return
    end
    local callbackName = remove and 'nt_actions:server:removeObjectPreset'
        or 'nt_actions:server:applyObjectPreset'
    local saved = lib.callback.await(callbackName, false, selectedModel, name)
    if saved ~= true then cb({ ok = false, error = 'The server rejected this preset change.' }) return end
    if remove then leavePose() end
    refreshLibrary()
    closePresetEditor(true)
    notify(remove
        and ('%s was removed from this object.'):format(name)
        or ('%s was applied to this object.'):format(name), 'success')
    cb({ ok = true })
end)

RegisterNUICallback('presetRename', function(data, cb)
    local oldName = type(data.oldName) == 'string' and data.oldName or nil
    local name = type(data.name) == 'string' and data.name or nil
    if not presetEditorActive or not oldName or not name or not presetCache[oldName] then
        cb({ ok = false, error = 'Select a preset and enter its new name.' })
        return
    end
    local saved = lib.callback.await('nt_actions:server:renamePreset', false, oldName, name)
    if saved ~= true then
        cb({ ok = false, error = 'That preset name is invalid or already exists.' })
        return
    end
    refreshLibrary()
    closePresetEditor(true)
    notify(('%s was renamed to %s.'):format(oldName, name), 'success')
    cb({ ok = true })
end)
RegisterNUICallback('groupEditorCancel', function(_, cb)
    if not groupEditorActive then cb({ ok = false }) return end
    closeGroupEditor(true)
    cb({ ok = true })
end)

RegisterNUICallback('groupEditorSave', function(data, cb)
    if not groupEditorActive or not canDeleteGroups or type(data.groups) ~= 'table' then
        cb({ ok = false, error = 'The group editor is not authorized.' })
        return
    end
    local saved = lib.callback.await('nt_actions:server:savePointGroups', false, selectedModel, data.groups)
    if saved ~= true then
        cb({ ok = false, error = 'The server rejected the group assignments. Check names and ensure pose groups contain points.' })
        return
    end
    refreshLibrary()
    closeGroupEditor(true)
    notify('Point groups were saved.', 'success')
    cb({ ok = true })
end)
local function editorOffsetValue(data)
    local value = type(data) == 'table' and data.offset or nil
    if type(value) ~= 'table' then return nil end
    local maximum = tonumber(ConfigTarget.MaxOffset) or 6.0
    local clean = {
        x = tonumber(value.x), y = tonumber(value.y), z = tonumber(value.z),
        heading = tonumber(value.heading),
    }
    if not clean.x or not clean.y or not clean.z or not clean.heading then return nil end
    if math.abs(clean.x) > maximum or math.abs(clean.y) > maximum or math.abs(clean.z) > maximum then return nil end
    clean.heading = clean.heading % 360.0
    return clean
end

RegisterNUICallback('moveSet', function(data, cb)
    if not fineTuneActive or editorMode ~= 'objectOffset' or editorMoveSetActive then cb({ ok = false }) return end
    local value = editorOffsetValue(data)
    if not value then cb({ ok = false, error = 'Enter valid offsets within the configured limit.' }) return end
    if not selectedScenario or not editorPointOffset then
        cb({ ok = false, error = 'This preset needs a pose and point before Move Set can be used.' })
        return
    end
    currentOffset = value
    if not previewEditorScenario() then cb({ ok = false }) return end
    local gameplayCameraCoords = GetGameplayCamCoord()
    local objectCoords = GetEntityCoords(selectedObject)
    local cameraOffset = combinedOffset(currentOffset, combinedOffset(editorPointOffset, poseOffsetFor(selectedScenario)))
    local _, heading = scenarioTransform(selectedObject, cameraOffset)
    startFineTuneCamera(objectCoords, gameplayCameraCoords, heading)
    editorMoveSetActive = true
    cb({ ok = true, offset = currentOffset })
end)

RegisterNUICallback('move', function(data, cb)
    if not fineTuneActive or not editorMoveSetActive or not currentOffset then cb({ ok = false }) return end
    local minimum = tonumber(ConfigTarget.FineTuneStepMin) or 0.005
    local maximum = tonumber(ConfigTarget.FineTuneStepMax) or 0.25
    local step = math.max(minimum, math.min(maximum, tonumber(data.step) or defaultEditorStep()))
    local maxOffset = tonumber(ConfigTarget.MaxOffset) or 6.0
    if data.direction == 'left' then currentOffset.x = currentOffset.x - step end
    if data.direction == 'right' then currentOffset.x = currentOffset.x + step end
    if data.direction == 'up' then currentOffset.y = currentOffset.y + step end
    if data.direction == 'down' then currentOffset.y = currentOffset.y - step end
    if data.direction == 'raise' then currentOffset.z = currentOffset.z + step end
    if data.direction == 'lower' then currentOffset.z = currentOffset.z - step end
    currentOffset.x = math.max(-maxOffset, math.min(maxOffset, currentOffset.x))
    currentOffset.y = math.max(-maxOffset, math.min(maxOffset, currentOffset.y))
    currentOffset.z = math.max(-maxOffset, math.min(maxOffset, currentOffset.z))
    cb({ ok = previewEditorScenario(), offset = currentOffset })
end)

RegisterNUICallback('rotate', function(data, cb)
    if not fineTuneActive or not editorMoveSetActive or not currentOffset then cb({ ok = false }) return end
    local minimum = tonumber(ConfigTarget.FineTuneStepMin) or 0.005
    local maximum = tonumber(ConfigTarget.FineTuneStepMax) or 0.25
    local movement = math.max(minimum, math.min(maximum, tonumber(data.step) or defaultEditorStep()))
    local step = movement * math.abs(tonumber(ConfigTarget.RotationStepMultiplier) or 200.0)
    if data.direction == 'counterclockwise' then currentOffset.heading = currentOffset.heading - step end
    if data.direction == 'clockwise' then currentOffset.heading = currentOffset.heading + step end
    currentOffset.heading = currentOffset.heading % 360.0
    cb({ ok = previewEditorScenario(), offset = currentOffset })
end)

RegisterNUICallback('cameraLook', function(_, cb)
    if not fineTuneActive or cameraLookActive then cb({ ok = false }) return end
    captureCameraOrbit()
    cameraLookActive = true
    cb({ ok = true })
    CreateThread(function()
        Wait(0)
        SetNuiFocus(false, false)
        local control = ConfigTarget.CameraControl or 0xF84FA74F
        local detected = false
        local timeout = GetGameTimer() + (tonumber(ConfigTarget.CameraHoldDetectionTimeout) or 5000)
        while fineTuneActive and cameraLookActive do
            DisableControlAction(0, control, true)
            local pressed = IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
            if pressed then detected = true end
            if (detected and not pressed) or (not detected and GetGameTimer() > timeout) then break end
            Wait(0)
        end
        cameraLookActive = false
        if fineTuneActive then
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'cameraEnd' })
        end
    end)
end)

RegisterNUICallback('cameraZoom', function(data, cb)
    if not fineTuneActive or not fineTuneCamera or not DoesCamExist(fineTuneCamera) then cb({ ok = false }) return end
    local minimum = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local maximum = math.max(minimum, tonumber(ConfigTarget.CameraZoomMax) or 8.0, tonumber(ConfigTarget.MaxOffset) or 6.0)
    orbitRadius = math.max(minimum, math.min(maximum, tonumber(data.distance) or orbitRadius))
    positionOrbitCamera(fineTuneCamera, cameraTargetCoords())
    cb({ ok = true, distance = orbitRadius })
end)

RegisterNUICallback('selectEditorCoord', function(data, cb)
    if not fineTuneActive or editorMode == 'poseOffset' or editorMode == 'objectOffset' or editorMode == 'coordOffset' then cb({ ok = false }) return end
    local coordNumber = tonumber(data.coordNumber)
    local selected = coordNumber and currentLibrary.offsets[coordNumber] or nil
    local pointIndex = tonumber(data.pointIndex)
    local point
    if pointIndex then
        point = availablePointOffsets[pointIndex]
        selected = point and point.offset or nil
    elseif selected then
        editorCoordNumber = coordNumber
    end
    if not selected then cb({ ok = false }) return end
    currentOffset = copyOffset(selected)
    local ok = startScenario(selectedObject, selectedScenario, currentOffset)
    cb({ ok = ok, offset = currentOffset })
end)

RegisterNUICallback('confirm', function(data, cb)
    if not fineTuneActive then cb({ ok = false }) return end
    if editorMode == 'coordOffset' then
        local point = currentLibrary.offsets[editorCoordNumber or selectedMenuCoord]
        local coordId = point and tonumber(point.id)
        if not coordId or not currentOffset then cb({ ok = false }) return end
        local saved = lib.callback.await('nt_actions:server:saveObjectCoordOffset', false, selectedModel, coordId, currentOffset)
        if type(saved) ~= 'table' then
            notify('The coordinate offset could not be saved.', 'error')
            cb({ ok = false })
            return
        end
        currentCoordOffsets[tostring(coordId)] = type(saved.offset) == 'table' and copyOffset(saved.offset) or nil
        if activePose and activePose.entity == selectedObject then startScenario(activePose.entity, activePose.scenario, activePose.offset) end
        closeFineTune()
        notify('The coordinate offset was saved.', 'success')
        cb({ ok = true })
        return
    end
    if editorMode == 'objectOffset' then
        local manualValue = editorOffsetValue(data)
        if manualValue then currentOffset = manualValue end
        if not currentOffset then cb({ ok = false }) return end
        local saved = lib.callback.await('nt_actions:server:saveObjectOffset', false, selectedModel, currentOffset)
        if type(saved) ~= 'table' then
            notify('The object offset could not be saved.', 'error')
            cb({ ok = false })
            return
        end
        currentObjectOffset = type(saved.offset) == 'table' and copyOffset(saved.offset) or nil
        if activePose and activePose.entity == selectedObject then
            startScenario(activePose.entity, activePose.scenario, activePose.offset)
        end
        closeFineTune()
        notify('The object offset was saved.', 'success')
        cb({ ok = true })
        return
    end
    if editorMode == 'poseOffset' then
        local saved = lib.callback.await(
            'nt_actions:server:savePoseOffset', false, selectedGroup, selectedScenario, currentOffset)
        if type(saved) ~= 'table' then
            notify('The global pose offset could not be saved.', 'error')
            cb({ ok = false })
            return
        end
        poseOffsets[selectedScenario] = saved.offset
        if saved.offset == nil then poseOffsets[selectedScenario] = nil end
        if activePose and activePose.scenario == selectedScenario then
            startScenario(activePose.entity, activePose.scenario, activePose.offset)
        end
        closeFineTune()
        notify(('%s global pose offset was saved.'):format(poseLabel(selectedGroup, configuredEntry(selectedGroup, selectedScenario))), 'success')
        cb({ ok = true })
        return
    end
    local saved = lib.callback.await(
        'nt_actions:server:saveObjectPose',
        false,
        selectedModel,
        selectedGroup,
        selectedScenario,
        currentOffset,
        editorMode,
        editorCoordNumber or 0,
        data.separate == true,
        currentLibrary.pointGroups[editorCoordNumber or selectedMenuCoord] or DEFAULT_POINT_GROUP,
        currentPreset
    )
    if type(saved) ~= 'table' then
        notify('The pose could not be saved.', 'error')
        cb({ ok = false })
        return
    end

    refreshLibrary()
    local savedCoordNumber = tonumber(saved.coordNumber)
    local savedOffset = savedCoordNumber and currentLibrary.offsets[savedCoordNumber] or currentOffset
    setActivePose({
        entity = selectedObject,
        model = selectedModel,
        group = selectedGroup,
        scenario = selectedScenario,
        coordNumber = savedCoordNumber,
        offset = copyOffset(savedOffset),
        origin = editorPreviousPose and copyTransform(editorPreviousPose.origin) or copyTransform(editorOrigin),
    })
    closeFineTune()
    notify(('%s and its object point were saved.'):format(prettyWords(selectedScenario)), 'success')
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    if fineTuneActive then
        closeFineTune()
        if editorPreviousPose and objectExists(editorPreviousPose.entity) then
            setActivePose(editorPreviousPose)
            startScenario(activePose.entity, activePose.scenario, activePose.offset)
        else
            finishPosePropCleanup(PlayerPedId())
            ClearPedTasksImmediately(PlayerPedId())
            if editorOrigin then
                SetEntityCoords(PlayerPedId(), editorOrigin.x, editorOrigin.y, editorOrigin.z, false, false, false, false)
                SetEntityHeading(PlayerPedId(), editorOrigin.heading)
            end
        end
    end
    cb({ ok = true })
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    exports.ox_target:removeGlobalObject(TARGET_OPTION)
    if posePropTracking then deleteTrackedPoseProps(PlayerPedId()) end
    if fineTuneActive then closeFineTune() end
    if groupEditorActive then closeGroupEditor(false) end
    if presetEditorActive then closePresetEditor(false) end
end)

-- Narrow client API used by the isolated batch-review feature.
NtActionsClient = NtActionsClient or {}
NtActionsClient.copyOffset = copyOffset
NtActionsClient.startScenario = startScenario
NtActionsClient.finishPosePropCleanup = finishPosePropCleanup
NtActionsClient.poseLabel = function(groupName, scenarioName, poseNumber)
    local entry = configuredEntry(groupName, scenarioName)
    if not entry then return prettyWords(scenarioName) end
    return numberedPoseLabel(groupName, entry, poseNumber)
end
