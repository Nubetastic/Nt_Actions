local TARGET_OPTION = 'nt_actions_object_poses'

local selectedObject
local selectedModel
local selectedGroup
local selectedScenario
local currentOffset
local currentLibrary = {}
local canDeleteGroups = false
local activePose
local editorPreviousPose
local editorOrigin
local availablePointOffset
local objectMenuVisible = false
local fineTuneActive = false
local editorOpening = false
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

-- Shared client state used by both the ox_target and L-key interfaces.
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

local function copyOffset(value)
    value = value or ConfigTarget.DefaultOffset or {}
    return {
        x = tonumber(value.x) or 0.0,
        y = tonumber(value.y) or 0.0,
        z = tonumber(value.z) or 0.0,
        heading = tonumber(value.heading) or 0.0,
    }
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
    local lock = entry and entry[2]
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
    if custom and custom ~= '' and custom ~= 'male' and custom ~= 'female' then return custom end

    local group = ConfigGroups.Scenario[groupName]
    for _, prefix in ipairs(group.truncate or {}) do
        if name:sub(1, #prefix) == prefix then return prettyWords(name:sub(#prefix + 1)) end
    end
    return prettyWords(name)
end

local function objectExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
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

local function poseOffset(groupName, scenarioName)
    local pose = currentLibrary[groupName] and currentLibrary[groupName][scenarioName]
    return pose and pose.offset or nil
end

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

local function findPointOffsetAtPlayer()
    local makeBlob = string.blob or function(length) return string.rep('\0', math.max(41, length)) end
    local buffer = makeBlob(256 * 4)
    local found = Citizen.InvokeNative(
        0x345EC3B7EBDE1CB5,
        GetEntityCoords(PlayerPedId()),
        tonumber(ConfigTarget.PointSearchDistance) or 0.5,
        buffer,
        16
    )
    if not found or found < 1 then return nil end

    local unpacked, pointId = pcall(string.unpack, '<i4', buffer, 9)
    if not unpacked or not pointId then return nil end
    local coords = Citizen.InvokeNative(0xA8452DD321607029, pointId, true, Citizen.ResultAsVector())
    if not coords then return nil end
    local heading = GetEntityHeading(PlayerPedId())
    if GetScenarioPointHeading then
        local ok, pointHeading = pcall(GetScenarioPointHeading, pointId, true)
        if ok and pointHeading then heading = pointHeading end
    end
    return pointToObjectOffset(coords, heading)
end

local function scenarioTransform(entity, offset)
    if not objectExists(entity) then return nil end
    local coords = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    local heading = (GetEntityHeading(entity) + offset.heading) % 360.0
    return coords, heading
end

local function startScenario(entity, scenarioName, offset)
    local coords, heading = scenarioTransform(entity, offset)
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

local function usePose(groupName, scenarioName)
    local offset = poseOffset(groupName, scenarioName)
    local origin = activePose and copyTransform(activePose.origin) or pedTransform(PlayerPedId())
    if not offset or not startScenario(selectedObject, scenarioName, offset) then
        notify('That object is no longer available.', 'error')
        return
    end
    setActivePose({
        entity = selectedObject,
        model = selectedModel,
        group = groupName,
        scenario = scenarioName,
        offset = copyOffset(offset),
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
        true,
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
        true,
        false
    )
    setActivePose(nil)
end

local function refreshLibrary()
    local response = lib.callback.await('nt_actions:server:getObjectLibrary', false, selectedModel) or {}
    local catalog = {}
    for _, groupName in ipairs(orderedGroups()) do
        catalog[groupName] = {}
        for _, entry in ipairs(groupPoses(groupName)) do
            if entry[1] then
                catalog[groupName][entry[1]] = {
                    show = false,
                    stored = false,
                }
            end
        end
    end

    local library = type(response.library) == 'table' and response.library or {}
    local offsets = type(library.offsets) == 'table' and library.offsets or {}
    local savedPoses = type(library.poses) == 'table' and library.poses or {}
    for _, visibility in ipairs({ 'show', 'noshow' }) do
        for groupName, poses in pairs(type(savedPoses[visibility]) == 'table' and savedPoses[visibility] or {}) do
            for scenarioName, offsetIndex in pairs(type(poses) == 'table' and poses or {}) do
                local pose = catalog[groupName] and catalog[groupName][scenarioName]
                local offset = offsets[tonumber(offsetIndex)]
                if pose and offset then
                    pose.stored = true
                    pose.show = visibility == 'show'
                    pose.offset = copyOffset(offset)
                end
            end
        end
    end

    currentLibrary = catalog
    canDeleteGroups = response.canDelete == true
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
    editorOpening = false
    cameraLookActive = false
    stopFineTuneCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function beginEditor(groupName, scenarioName, mode)
    if not objectExists(selectedObject) then
        notify('That object is no longer available.', 'error')
        return
    end

    if mode == 'add' then
        poseMenuBlockedUntil = GetGameTimer() + math.max(
            0,
            math.floor(tonumber(ConfigTarget.AddPoseMenuDelay) or 5000)
        )
    end

    objectMenuVisible = false
    selectedGroup = groupName
    selectedScenario = scenarioName
    editorPreviousPose = activePose and {
        entity = activePose.entity,
        model = activePose.model,
        group = activePose.group,
        scenario = activePose.scenario,
        offset = copyOffset(activePose.offset),
        origin = copyTransform(activePose.origin),
    } or nil
    editorOrigin = pedTransform(PlayerPedId())
    local savedOffset = poseOffset(groupName, scenarioName)
    local activeObjectOffset = mode == 'add'
        and activePose
        and activePose.entity == selectedObject
        and activePose.offset
        or nil
    currentOffset = copyOffset(savedOffset or activeObjectOffset)
    availablePointOffset = nil
    editorOpening = true

    NtMenu.hide(false)
    if not startScenario(selectedObject, selectedScenario, currentOffset) then
        editorOpening = false
        return
    end

    Wait(math.max(0, math.floor(tonumber(ConfigTarget.PointSearchDelay) or 3000)))
    if not objectExists(selectedObject) then
        editorOpening = false
        ClearPedTasksImmediately(PlayerPedId())
        notify('That object is no longer available.', 'error')
        return
    end
    availablePointOffset = findPointOffsetAtPlayer()

    local gameplayCameraCoords = GetGameplayCamCoord()
    local objectCoords = GetEntityCoords(selectedObject)
    local _, heading = scenarioTransform(selectedObject, currentOffset)
    startFineTuneCamera(objectCoords, gameplayCameraCoords, heading)
    fineTuneActive = true
    editorOpening = false
    local cameraZoomMin = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local cameraZoomMax = math.max(cameraZoomMin, tonumber(ConfigTarget.CameraZoomMax) or 8.0, orbitRadius)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        editorTitle = mode == 'modify'
            and (editorSettings.ModifyTitle or 'Modify pose')
            or (editorSettings.AddTitle or 'Add pose'),
        scale = NtMenu.getScale(),
        pointAvailable = availablePointOffset ~= nil,
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
    })
end

local function openAddPoseMenu(groupName)
    objectMenuVisible = false
    local options = {}
    for _, entry in ipairs(groupPoses(groupName)) do
        local scenarioName = entry[1]
        local pose = scenarioName and currentLibrary[groupName] and currentLibrary[groupName][scenarioName]
        if pose and not pose.stored and compatible(entry) then
            options[#options + 1] = {
                label = poseLabel(groupName, entry),
                description = groupName,
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
            local scenarioName = entry[1]
            local pose = scenarioName and currentLibrary[groupName] and currentLibrary[groupName][scenarioName]
            if pose and not pose.stored and compatible(entry) then available = available + 1 end
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
    for _, poses in pairs(currentLibrary) do
        for _, pose in pairs(poses) do
            if pose.stored and not pose.show then count = count + 1 end
        end
    end
    return count
end

local function openUndoMenu()
    if not canDeleteGroups then return end
    objectMenuVisible = false
    local options = {}
    for _, groupName in ipairs(orderedGroups()) do
        for _, entry in ipairs(groupPoses(groupName)) do
            local pose = entry[1] and currentLibrary[groupName] and currentLibrary[groupName][entry[1]]
            if pose and pose.stored and not pose.show then
                local label = poseLabel(groupName, entry)
                options[#options + 1] = {
                    label = label,
                    description = groupName,
                    disabled = true,
                    restorable = true,
                    args = {
                        group = groupName,
                        scenario = entry[1],
                        poseLabel = label,
                    },
                }
            end
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
                args.scenario
            )
            if not restored then
                notify('You do not have permission to restore that pose.', 'error')
                return
            end
            notify(('%s was restored to this object.'):format(args.poseLabel or 'Pose'), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
    })
end

openObjectMenu = function(entity)
    if fineTuneActive or not objectExists(entity) then return end
    selectedObject = entity
    selectedModel = GetEntityModel(entity)
    refreshLibrary()
    objectMenuVisible = true

    local options = {}
    for _, groupName in ipairs(orderedGroups()) do
        for _, entry in ipairs(groupPoses(groupName)) do
            local pose = entry[1] and currentLibrary[groupName] and currentLibrary[groupName][entry[1]]
            if pose and pose.show and compatible(entry) then
                local label = poseLabel(groupName, entry)
                options[#options + 1] = {
                    label = label,
                    description = groupName,
                    deletable = canDeleteGroups,
                    args = {
                        action = 'pose',
                        group = groupName,
                        scenario = entry[1],
                        poseLabel = label,
                    },
                }
            end
        end
    end
    if #options == 0 then
        options[1] = { label = configuredText('Empty', 'No poses added to this object'), disabled = true }
    end

    local isActiveObject = activePose and activePose.entity == selectedObject
    local footer = {
        { label = configuredText('AddPose', 'Add Pose'), args = { action = 'add' } },
    }
    if isActiveObject then
        footer[#footer + 1] = { label = configuredText('Modify', 'Modify'), args = { action = 'modify' } }
        footer[#footer + 1] = { label = configuredText('Leave', 'Leave Pose'), args = { action = 'leave' } }
    elseif inPose then
        footer[#footer + 1] = { label = configuredText('Leave', 'Leave Pose'), args = { action = 'leave' } }
        footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), args = { action = 'exit' } }
    else
        footer[#footer + 1] = { label = configuredText('Exit', 'Exit'), args = { action = 'exit' } }
    end
    if canDeleteGroups then
        footer[#footer + 1] = {
            label = configuredText('Undo', 'Undo'),
            disabled = hiddenPoseCount() == 0,
            args = { action = 'undo' },
        }
    end

    NtMenu.open(configuredText('ObjectTitle', 'Object Poses'), options, function(_, args)
        if args.action == 'pose' then usePose(args.group, args.scenario) end
    end, function()
        objectMenuVisible = false
    end, {
        footerActions = footer,
        onFooter = function(_, args)
            if args.action == 'add' then
                openAddGroupMenu()
            elseif args.action == 'modify' and activePose then
                beginEditor(activePose.group, activePose.scenario, 'modify')
            elseif args.action == 'leave' then
                leavePose()
                objectMenuVisible = false
                NtMenu.hide(false)
            elseif args.action == 'exit' then
                objectMenuVisible = false
                NtMenu.hide(false)
            elseif args.action == 'undo' then
                openUndoMenu()
            end
        end,
        onDelete = function(_, args)
            objectMenuVisible = false
            local removed = lib.callback.await(
                'nt_actions:server:hideObjectPose',
                false,
                selectedModel,
                args.group,
                args.scenario
            )
            if not removed then
                objectMenuVisible = true
                notify('You do not have permission to remove that pose.', 'error')
                return
            end
            if activePose
                and activePose.entity == selectedObject
                and activePose.group == args.group
                and activePose.scenario == args.scenario
            then
                leavePose()
            end
            notify(('%s was hidden from this object.'):format(args.poseLabel or 'Pose'), 'success')
            NtMenu.hide(false)
            openObjectMenu(selectedObject)
        end,
    })
end

AddEventHandler('nt_actions:client:openCachedPoseList', function()
    if not inPose or not objectExists(cachedPoseObject) then
        setActivePose(nil)
        notify('The object for the active pose is no longer available.', 'error')
        return
    end
    openObjectMenu(cachedPoseObject)
end)

RegisterNetEvent('nt_actions:client:objectLibraryUpdated', function(model)
    if objectMenuVisible and selectedModel == model and objectExists(selectedObject) then
        NtMenu.hide(false)
        openObjectMenu(selectedObject)
    end
end)

CreateThread(function()
    Wait(0)
    exports.ox_target:addGlobalObject({
        {
            name = TARGET_OPTION,
            icon = ConfigTarget.TargetIcon,
            label = ConfigTarget.TargetLabel,
            distance = ConfigTarget.TargetDistance,
            canInteract = function()
                return not fineTuneActive
            end,
            onSelect = function(data)
                openObjectMenu(data.entity)
            end,
        },
    })
end)

RegisterNUICallback('move', function(data, cb)
    if not fineTuneActive or not currentOffset then cb({ ok = false }) return end
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
    cb({ ok = startScenario(selectedObject, selectedScenario, currentOffset), offset = currentOffset })
end)

RegisterNUICallback('rotate', function(data, cb)
    if not fineTuneActive or not currentOffset then cb({ ok = false }) return end
    local minimum = tonumber(ConfigTarget.FineTuneStepMin) or 0.005
    local maximum = tonumber(ConfigTarget.FineTuneStepMax) or 0.25
    local movement = math.max(minimum, math.min(maximum, tonumber(data.step) or defaultEditorStep()))
    local step = movement * math.abs(tonumber(ConfigTarget.RotationStepMultiplier) or 200.0)
    if data.direction == 'counterclockwise' then currentOffset.heading = currentOffset.heading - step end
    if data.direction == 'clockwise' then currentOffset.heading = currentOffset.heading + step end
    currentOffset.heading = currentOffset.heading % 360.0
    cb({ ok = startScenario(selectedObject, selectedScenario, currentOffset), offset = currentOffset })
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

RegisterNUICallback('pointCoords', function(_, cb)
    if not fineTuneActive or not availablePointOffset then cb({ ok = false }) return end
    currentOffset = copyOffset(availablePointOffset)
    local ok = startScenario(selectedObject, selectedScenario, currentOffset)
    cb({ ok = ok, offset = currentOffset })
end)

RegisterNUICallback('confirm', function(_, cb)
    if not fineTuneActive then cb({ ok = false }) return end
    local saved = lib.callback.await(
        'nt_actions:server:saveObjectPose',
        false,
        selectedModel,
        selectedGroup,
        selectedScenario,
        currentOffset
    )
    if not saved then
        notify('The pose could not be saved.', 'error')
        cb({ ok = false })
        return
    end

    refreshLibrary()
    local savedOffset = poseOffset(selectedGroup, selectedScenario) or currentOffset
    setActivePose({
        entity = selectedObject,
        model = selectedModel,
        group = selectedGroup,
        scenario = selectedScenario,
        offset = copyOffset(savedOffset),
        origin = editorPreviousPose and copyTransform(editorPreviousPose.origin) or copyTransform(editorOrigin),
    })
    closeFineTune()
    notify(('%s is now available on this object.'):format(prettyWords(selectedScenario)), 'success')
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    if fineTuneActive then
        closeFineTune()
        if editorPreviousPose and objectExists(editorPreviousPose.entity) then
            setActivePose(editorPreviousPose)
            startScenario(activePose.entity, activePose.scenario, activePose.offset)
        else
            setActivePose(nil)
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

CreateThread(function()
    while true do
        Wait(750)
        if activePose and not fineTuneActive and not editorOpening
            and (not objectExists(activePose.entity) or not IsPedActiveInScenario(PlayerPedId()))
        then
            finishPosePropCleanup(PlayerPedId())
            setActivePose(nil)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    exports.ox_target:removeGlobalObject(TARGET_OPTION)
    if posePropTracking then deleteTrackedPoseProps(PlayerPedId()) end
    if fineTuneActive then closeFineTune() end
end)
