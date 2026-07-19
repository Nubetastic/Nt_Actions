local TARGET_OPTION = 'nt_actions_object_target_once'

local selectedObject
local selectedModel
local selectedGroup
local selectedScenario
local currentOffset
local originalPlayerCoords
local targetActive = false
local fineTuneActive = false
local cameraLookActive = false
local fineTuneCamera
local orbitRadius = 1.0
local orbitYaw = 0.0
local orbitPitch = 0.0

local function setMenuOpen(value)
    TriggerEvent('nt_actions:client:setMenuOpen', value)
end

local function copyDefaultOffset()
    local value = ConfigTarget.DefaultOffset or {}
    return {
        x = tonumber(value.x) or 0.0,
        y = tonumber(value.y) or 0.0,
        z = tonumber(value.z) or 0.0,
        heading = tonumber(value.heading) or 0.0,
    }
end

local function notify(description, notificationType)
    lib.notify({
        title = 'Object Target',
        description = description,
        type = notificationType or 'inform',
    })
end

local function removeObjectTarget()
    if not targetActive then return end
    exports.ox_target:removeGlobalObject(TARGET_OPTION)
    targetActive = false
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

local function getGenderLock(entry)
    local lock = entry and entry[2]
    if lock == 'male' or lock == 'female' then return lock end
end

local function isCompatible(entry)
    local lock = getGenderLock(entry)
    if not lock then return true end
    local male = IsPedMale(PlayerPedId())
    return (lock == 'male' and male) or (lock == 'female' and not male)
end

local function displayLabel(groupKey, group, entry)
    local name = entry[1]
    local custom = entry[2]
    if custom and custom ~= '' and custom ~= 'male' and custom ~= 'female' then
        return custom
    end
    for _, prefix in ipairs(group.truncate or {}) do
        if name:sub(1, #prefix) == prefix then
            return name:sub(#prefix + 1)
        end
    end
    local prefix = tostring(groupKey) .. '_'
    if name:sub(1, #prefix) == prefix then
        return name:sub(#prefix + 1)
    end
    return name
end

local function objectStillExists()
    return selectedObject and selectedObject ~= 0 and DoesEntityExist(selectedObject)
end

local function scenarioTransform()
    if not objectStillExists() then return end
    local coords = GetOffsetFromEntityInWorldCoords(
        selectedObject,
        currentOffset.x,
        currentOffset.y,
        currentOffset.z
    )
    local heading = (GetEntityHeading(selectedObject) + currentOffset.heading) % 360.0
    return coords, heading
end

local function startSelectedScenario()
    local coords, heading = scenarioTransform()
    if not coords then
        notify('That object is no longer available.', 'error')
        return false
    end

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    Wait(50)
    Citizen.InvokeNative(
        0x4D1F61FC34AF3CD1,
        ped,
        GetHashKey(selectedScenario),
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
    local dx = cameraCoords.x - target.x
    local dy = cameraCoords.y - target.y
    local dz = cameraCoords.z - target.z
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
    local originalLookZ = anchor.z + (tonumber(ConfigTarget.CameraLookAtHeight) or 0.75)
    local currentHorizontalDistance = math.sqrt(
        ((gameplayCameraCoords.x - anchor.x) ^ 2) +
        ((gameplayCameraCoords.y - anchor.y) ^ 2)
    )
    local currentHeight = gameplayCameraCoords.z - originalLookZ
    local minimumPitch = math.rad(tonumber(ConfigTarget.CameraMinPitch) or -60.0)
    local maximumPitch = math.rad(tonumber(ConfigTarget.CameraMaxPitch) or 75.0)

    orbitRadius = math.max(0.5, tonumber(ConfigTarget.MaxOffset) or 3.0)
    orbitYaw = math.rad((scenarioHeading or 0.0) - 90.0)
    orbitPitch = math.max(minimumPitch, math.min(maximumPitch, math.atan(currentHeight, currentHorizontalDistance)))

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
                local sensitivity = math.rad(tonumber(ConfigTarget.CameraOrbitSensitivity) or 3.0)
                local lookX = GetControlNormal(0, ConfigTarget.CameraLookX or 0xA987235F)
                local lookY = GetControlNormal(0, ConfigTarget.CameraLookY or 0xD2047988)
                local minimumPitch = math.rad(tonumber(ConfigTarget.CameraMinPitch) or -60.0)
                local maximumPitch = math.rad(tonumber(ConfigTarget.CameraMaxPitch) or 75.0)

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
    cameraLookActive = false
    stopFineTuneCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openFineTune()
    local gameplayCameraCoords = GetGameplayCamCoord()
    local _, scenarioHeading = scenarioTransform()
    if not scenarioHeading then return end
    if not startSelectedScenario() then
        return
    end
    startFineTuneCamera(originalPlayerCoords, gameplayCameraCoords, scenarioHeading)
    fineTuneActive = true
    local cameraZoomMin = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local cameraZoomMax = math.max(cameraZoomMin, tonumber(ConfigTarget.CameraZoomMax) or 8.0, orbitRadius)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        step = ConfigTarget.FineTuneStep,
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

local function selectScenario(scenarioName)
    selectedScenario = scenarioName
    NtMenu.hide(false)
    setMenuOpen(false)
    originalPlayerCoords = GetEntityCoords(PlayerPedId())
    CachedGroupKey = selectedGroup
    CachedAnchor = nil
    inTempScenario = false
    openFineTune()
end

local function openScenarioMenu(categoryName)
    local group = ConfigGroups.Scenario[selectedGroup]
    local entries = categoryName and group.Scenarios[categoryName] or group
    local options = {}

    for _, entry in ipairs(entries or {}) do
        if type(entry) == 'table' and entry[1] and isCompatible(entry) then
            options[#options + 1] = {
                label = displayLabel(selectedGroup, group, entry),
                args = { scenarioName = entry[1] },
            }
        end
    end

    if #options == 0 then
        options[1] = { label = 'No compatible scenarios', args = {} }
    end

    NtMenu.open(categoryName or selectedGroup, options, function(_, args)
        if args.scenarioName then selectScenario(args.scenarioName) end
    end)
end

local function openCategoryMenu()
    local group = ConfigGroups.Scenario[selectedGroup]
    if not group.Scenarios then
        openScenarioMenu(nil)
        return
    end

    local options = {}
    local categoryOrder = group.CategoryOrder or sortedKeys(group.Scenarios)
    local included = {}
    for _, categoryName in ipairs(categoryOrder) do
        local categoryScenarios = group.Scenarios[categoryName]
        local compatible = false
        for _, entry in ipairs(categoryScenarios or {}) do
            if isCompatible(entry) then
                compatible = true
                break
            end
        end
        if categoryScenarios and compatible then
            included[categoryName] = true
            options[#options + 1] = {
                label = categoryName,
                args = { categoryName = categoryName },
            }
        end
    end
    for _, categoryName in ipairs(sortedKeys(group.Scenarios)) do
        if not included[categoryName] then
            local compatible = false
            for _, entry in ipairs(group.Scenarios[categoryName]) do
                if isCompatible(entry) then
                    compatible = true
                    break
                end
            end
            if compatible then
                options[#options + 1] = {
                    label = categoryName,
                    args = { categoryName = categoryName },
                }
            end
        end
    end

    NtMenu.open(selectedGroup, options, function(_, args)
        if args.categoryName then openScenarioMenu(args.categoryName) end
    end)
end

local function chooseGroup(groupName)
    selectedGroup = groupName
    local saved = lib.callback.await('nt_actions:server:getObjectOffset', false, selectedModel, groupName)
    currentOffset = saved or copyDefaultOffset()
    openCategoryMenu()
end

local function openGroupMenu()
    local options = {}
    local configuredGroups = ConfigGroups and ConfigGroups.Scenario or {}
    local groupOrder = ConfigGroups and ConfigGroups.ScenarioOrder or sortedKeys(configuredGroups)
    local included = {}
    for _, groupName in ipairs(groupOrder) do
        if configuredGroups[groupName] then
            included[groupName] = true
            options[#options + 1] = {
                label = groupName,
                args = { groupName = groupName },
            }
        end
    end
    for _, groupName in ipairs(sortedKeys(configuredGroups)) do
        if not included[groupName] then
            options[#options + 1] = {
                label = groupName,
                args = { groupName = groupName },
            }
        end
    end

    NtMenu.open('Choose Scenario Group', options, function(_, args)
        if args.groupName then chooseGroup(args.groupName) end
    end)
end

local function useTargetedObject(entity)
    removeObjectTarget()
    setMenuOpen(false)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        notify('No valid object was selected.', 'error')
        return
    end
    selectedObject = entity
    selectedModel = GetEntityModel(entity)
    selectedGroup = nil
    selectedScenario = nil
    currentOffset = copyDefaultOffset()
    openGroupMenu()
end

AddEventHandler('nt_actions:client:startObjectTarget', function()
    if fineTuneActive then return end
    removeObjectTarget()
    targetActive = true
    exports.ox_target:addGlobalObject({
        {
            name = TARGET_OPTION,
            icon = ConfigTarget.TargetIcon,
            label = ConfigTarget.TargetLabel,
            distance = ConfigTarget.TargetDistance,
            onSelect = function(data)
                useTargetedObject(data.entity)
            end,
        },
    })
    notify('Aim at an object and select the target option. It can be used once.')
end)

RegisterNUICallback('move', function(data, cb)
    if not fineTuneActive or not currentOffset then
        cb({ ok = false })
        return
    end

    local minimumStep = tonumber(ConfigTarget.FineTuneStepMin) or 0.005
    local maximumStep = tonumber(ConfigTarget.FineTuneStepMax) or 0.25
    local step = tonumber(data.step) or tonumber(ConfigTarget.FineTuneStep) or 0.025
    step = math.max(minimumStep, math.min(maximumStep, step))
    local maxOffset = tonumber(ConfigTarget.MaxOffset) or 3.0
    if data.direction == 'left' then currentOffset.x = currentOffset.x - step end
    if data.direction == 'right' then currentOffset.x = currentOffset.x + step end
    if data.direction == 'up' then currentOffset.y = currentOffset.y + step end
    if data.direction == 'down' then currentOffset.y = currentOffset.y - step end
    if data.direction == 'raise' then currentOffset.z = currentOffset.z + step end
    if data.direction == 'lower' then currentOffset.z = currentOffset.z - step end
    currentOffset.x = math.max(-maxOffset, math.min(maxOffset, currentOffset.x))
    currentOffset.y = math.max(-maxOffset, math.min(maxOffset, currentOffset.y))
    currentOffset.z = math.max(-maxOffset, math.min(maxOffset, currentOffset.z))

    local ok = startSelectedScenario()
    cb({ ok = ok, offset = currentOffset })
end)

RegisterNUICallback('rotate', function(data, cb)
    if not fineTuneActive or not currentOffset then
        cb({ ok = false })
        return
    end

    local minimumStep = tonumber(ConfigTarget.FineTuneStepMin) or 0.005
    local maximumStep = tonumber(ConfigTarget.FineTuneStepMax) or 0.25
    local movementStep = tonumber(data.step) or tonumber(ConfigTarget.FineTuneStep) or 0.025
    movementStep = math.max(minimumStep, math.min(maximumStep, movementStep))
    local multiplier = math.abs(tonumber(ConfigTarget.RotationStepMultiplier) or 200.0)
    local step = movementStep * multiplier
    if data.direction == 'counterclockwise' then currentOffset.heading = currentOffset.heading - step end
    if data.direction == 'clockwise' then currentOffset.heading = currentOffset.heading + step end
    currentOffset.heading = currentOffset.heading % 360.0

    local ok = startSelectedScenario()
    cb({ ok = ok, offset = currentOffset })
end)

RegisterNUICallback('cameraLook', function(_, cb)
    if not fineTuneActive or cameraLookActive then
        cb({ ok = false })
        return
    end

    captureCameraOrbit()
    cameraLookActive = true
    cb({ ok = true })

    CreateThread(function()
        Wait(0)
        SetNuiFocus(false, false)

        local cameraControl = ConfigTarget.CameraControl or 0xF84FA74F
        local detectedPress = false
        local detectionTimeout = GetGameTimer() + (tonumber(ConfigTarget.CameraHoldDetectionTimeout) or 5000)

        while fineTuneActive and cameraLookActive do
            DisableControlAction(0, cameraControl, true)
            local pressed = IsDisabledControlPressed(0, cameraControl) or IsControlPressed(0, cameraControl)
            if pressed then detectedPress = true end

            if detectedPress and not pressed then break end
            if not detectedPress and GetGameTimer() > detectionTimeout then break end
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
    if not fineTuneActive or not fineTuneCamera or not DoesCamExist(fineTuneCamera) then
        cb({ ok = false })
        return
    end

    local minimum = tonumber(ConfigTarget.CameraZoomMin) or 0.75
    local maximum = math.max(minimum, tonumber(ConfigTarget.CameraZoomMax) or 8.0, tonumber(ConfigTarget.MaxOffset) or 3.0)
    orbitRadius = math.max(minimum, math.min(maximum, tonumber(data.distance) or orbitRadius))
    positionOrbitCamera(fineTuneCamera, cameraTargetCoords())
    cb({ ok = true, distance = orbitRadius })
end)

RegisterNUICallback('confirm', function(data, cb)
    if fineTuneActive and data.save then
        TriggerServerEvent('nt_actions:server:saveObjectOffset', selectedModel, selectedGroup, currentOffset)
        notify('Offset saved for this object model and scenario group.', 'success')
    end
    closeFineTune()
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    if fineTuneActive then
        ClearPedTasksImmediately(PlayerPedId())
        if originalPlayerCoords then
            SetEntityCoords(PlayerPedId(), originalPlayerCoords.x, originalPlayerCoords.y, originalPlayerCoords.z, false, false, false, false)
        end
    end
    closeFineTune()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeObjectTarget()
    if fineTuneActive then closeFineTune() end
end)
