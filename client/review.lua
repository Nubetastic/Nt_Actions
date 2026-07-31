NtReview = NtReview or {}

local settings = ConfigTarget.BatchReview or {}
local pages = {}
local pageIndex = 1
local checked = {}
local reviewObject
local reviewCamera
local reviewOrigin
local cameraRadius = tonumber(settings.CameraDistance) or 3.0
local cameraYaw = 0.0
local cameraPitch = 0.15
local cameraLookActive = false
local reviewActive = false
local presetStates = {}

local function notify(description, notificationType)
    lib.notify({ title = 'Upload Review', description = description, type = notificationType or 'inform' })
end

local function pedTransform()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
end

local function objectExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function cameraTarget()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z + 0.75 }
end

local function positionCamera()
    if not reviewCamera or not DoesCamExist(reviewCamera) then return end
    local target = cameraTarget()
    local horizontal = cameraRadius * math.cos(cameraPitch)
    SetCamCoord(
        reviewCamera,
        target.x + math.cos(cameraYaw) * horizontal,
        target.y + math.sin(cameraYaw) * horizontal,
        target.z + math.sin(cameraPitch) * cameraRadius
    )
    PointCamAtCoord(reviewCamera, target.x, target.y, target.z)
end

local function stopCamera()
    cameraLookActive = false
    if not reviewCamera then return end
    local camera = reviewCamera
    reviewCamera = nil
    RenderScriptCams(false, true, 200, true, true)
    CreateThread(function()
        Wait(200)
        if DoesCamExist(camera) then DestroyCam(camera, false) end
    end)
end

local function startCamera()
    stopCamera()
    cameraRadius = tonumber(settings.CameraDistance) or 3.0
    cameraYaw = math.rad(GetEntityHeading(PlayerPedId()) - 90.0)
    cameraPitch = 0.15
    reviewCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(reviewCamera, tonumber(ConfigTarget.CameraFov) or 50.0)
    positionCamera()
    SetCamActive(reviewCamera, true)
    RenderScriptCams(true, true, 200, true, true)
    local camera = reviewCamera
    CreateThread(function()
        while reviewCamera == camera and DoesCamExist(camera) do
            positionCamera()
            Wait(0)
        end
    end)
end

local function restoreOrigin()
    if not reviewOrigin then return end
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    NetworkResurrectLocalPlayer(
        reviewOrigin.x, reviewOrigin.y, reviewOrigin.z, reviewOrigin.heading, false, false)
    SetEntityHealth(PlayerPedId(), health)
end

local function cleanupPreview(restorePlayer)
    stopCamera()
    local ped = PlayerPedId()
    if NtActionsClient and NtActionsClient.finishPosePropCleanup then
        NtActionsClient.finishPosePropCleanup(ped)
    end
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)
    if restorePlayer ~= false then restoreOrigin() end
    if objectExists(reviewObject) then
        SetEntityAsMissionEntity(reviewObject, true, true)
        DeleteObject(reviewObject)
        if objectExists(reviewObject) then DeleteEntity(reviewObject) end
    end
    reviewObject = nil
end

local function endReview(closeMenu)
    cleanupPreview(true)
    reviewActive = false
    pages, checked, presetStates, pageIndex, reviewOrigin = {}, {}, {}, 1, nil
    lib.callback.await('nt_actions:server:endReview', false)
    if closeMenu then NtMenu.hide(false) end
end

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + (tonumber(settings.ModelLoadTimeout) or 10000)
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model)
end

local function spawnReviewObject(model)
    cleanupPreview(true)
    local ped = PlayerPedId()
    if not loadModel(model) then return false end
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, tonumber(settings.SpawnDistance) or 2.5, 0.0)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    if found then coords = vector3(coords.x, coords.y, groundZ) end
    reviewObject = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
    SetModelAsNoLongerNeeded(model)
    if not objectExists(reviewObject) then return false end
    SetEntityHeading(reviewObject, GetEntityHeading(ped))
    FreezeEntityPosition(reviewObject, true)
    SetEntityAsMissionEntity(reviewObject, true, true)
    startCamera()
    return true
end

local function previewPose(pose, offset)
    if not objectExists(reviewObject) or not NtActionsClient then return end
    if not offset then notify('Select a current or new point before previewing a pose.', 'error') return end
    local ok = NtActionsClient.startScenario(reviewObject, pose.scenario, offset)
    if not ok then notify('That pose could not be previewed.', 'error') end
end

local openPresetPage

local function pageState(page)
    checked[page.key] = checked[page.key] or { poses = {}, coords = {}, selectedCoordinate = 1 }
    return checked[page.key]
end

local function coordDescription(offset)
    return ('x %.3f  y %.3f  z %.3f  heading %.1f'):format(
        tonumber(offset.x) or 0.0,
        tonumber(offset.y) or 0.0,
        tonumber(offset.z) or 0.0,
        tonumber(offset.heading) or 0.0
    )
end

local function reviewerGender()
    return IsPedMale(PlayerPedId()) and 'male' or 'female'
end

local function poseCompatible(pose)
    return not pose.gender or pose.gender == reviewerGender()
end

local function genderLabel(gender)
    return gender == 'male' and 'Male' or gender == 'female' and 'Female' or nil
end

local function beginCameraLook()
    if not reviewActive or cameraLookActive or not reviewCamera then return end
    cameraLookActive = true
    SetNuiFocus(false, false)
    CreateThread(function()
        local control = ConfigTarget.CameraControl or 0xF84FA74F
        local detected = false
        local timeout = GetGameTimer() + 5000
        while reviewActive and cameraLookActive and reviewCamera do
            DisableControlAction(0, control, true)
            local pressed = IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
            if pressed then detected = true end
            if (detected and not pressed) or (not detected and GetGameTimer() > timeout) then break end
            local sensitivity = math.rad(tonumber(ConfigTarget.CameraOrbitSensitivity) or 4.0)
            cameraYaw = cameraYaw - (GetDisabledControlNormal(0, ConfigTarget.CameraLookX or 0xA987235F) * sensitivity)
            cameraPitch = math.max(-1.0, math.min(1.2,
                cameraPitch + (GetDisabledControlNormal(0, ConfigTarget.CameraLookY or 0xD2047988) * sensitivity)))
            positionCamera()
            Wait(0)
        end
        cameraLookActive = false
        if reviewActive then SetNuiFocus(true, true) end
    end)
end

local function presetPageState(page)
    presetStates[page.key] = presetStates[page.key] or {
        objectIndex = 1,
        existingPreset = '',
        replacePreset = false,
        checkedPoses = {},
        checkedObjects = {},
        compareOpen = false,
    }
    return presetStates[page.key]
end

openPresetPage = function()
    local page = pages[pageIndex]
    if not page then endReview(true) return end
    local state = presetPageState(page)
    state.objectIndex = math.max(1, math.min(#(page.objects or {}), tonumber(state.objectIndex) or 1))
    local displayedObject = page.objects[state.objectIndex]
    local definition = page.candidateDefinition or { currentCoords = {}, poses = {} }

    NtMenu.hide(false)
    if displayedObject and not spawnReviewObject(displayedObject.item) then
        notify(('Model %s could not be spawned.'):format(displayedObject.item), 'error')
    elseif not displayedObject then
        cleanupPreview(true)
    end

    local options = {}
    for _, pose in ipairs(definition.poses or {}) do
        local compatible = poseCompatible(pose)
        options[#options + 1] = {
            label = NtActionsClient.poseLabel(pose.group, pose.scenario),
            rightLabel = not compatible and genderLabel(pose.gender) or pose.visibility == 'noshow' and 'Hidden' or nil,
            description = ('%s - %s'):format(pose.group, pose.pointGroup or 'Group 1'),
            disabled = not compatible or pose.visibility == 'noshow',
            args = compatible and pose.visibility ~= 'noshow' and { pose = pose } or nil,
        }
    end
    local coordinateOptions = {}
    local groupCounts = {}
    for _, point in ipairs(definition.currentCoords or {}) do
        local pointGroup = point.pointGroup or 'Group 1'
        groupCounts[pointGroup] = (groupCounts[pointGroup] or 0) + 1
        coordinateOptions[#coordinateOptions + 1] = {
            label = tostring(groupCounts[pointGroup]), pointGroup = pointGroup,
            title = ('%s point %d - %s'):format(pointGroup, groupCounts[pointGroup], coordDescription(point.offset)),
            args = { offset = point.offset },
        }
    end
    local normalState = pageState(page)
    normalState.selectedCoordinate = math.max(1, math.min(#coordinateOptions, tonumber(normalState.selectedCoordinate) or 1))

    local footer = {
        { label = 'Back Preset', disabled = pageIndex <= 1, args = { action = 'back' } },
        { label = 'Next Preset', disabled = pageIndex >= #pages, args = { action = 'next' } },
        { label = 'Previous Object', disabled = #(page.objects or {}) < 2, args = { action = 'previousObject' } },
        { label = 'Next Object', disabled = #(page.objects or {}) < 2, args = { action = 'nextObject' } },
        { label = 'Compare', args = { action = 'compare' } },
    }
    NtMenu.open(('Preset Review %d/%d - %s'):format(pageIndex, #pages, page.candidateName), options,
        function(_, args)
            local coordinate = coordinateOptions[normalState.selectedCoordinate]
            previewPose(args.pose, coordinate and coordinate.args.offset or nil)
        end,
        function() endReview(false) end,
        {
            footerActions = footer,
            coordinateOptions = coordinateOptions,
            selectedCoordinate = normalState.selectedCoordinate,
            showReviewCamera = displayedObject ~= nil,
            reviewCameraDistance = cameraRadius,
            reviewCameraMin = tonumber(settings.CameraZoomMin) or 0.75,
            reviewCameraMax = tonumber(settings.CameraZoomMax) or 8.0,
            reviewCameraStep = tonumber(settings.CameraZoomStep) or 0.25,
            onCoordinateSelect = function(index) normalState.selectedCoordinate = index end,
            onReviewZoom = function(distance)
                local minimum = tonumber(settings.CameraZoomMin) or 0.75
                local maximum = tonumber(settings.CameraZoomMax) or 8.0
                cameraRadius = math.max(minimum, math.min(maximum, tonumber(distance) or cameraRadius))
                positionCamera()
            end,
            onCameraLook = beginCameraLook,
            onFooter = function(_, args)
                if args.action == 'back' then pageIndex = pageIndex - 1; openPresetPage()
                elseif args.action == 'next' then pageIndex = pageIndex + 1; openPresetPage()
                elseif args.action == 'previousObject' and #page.objects > 0 then
                    state.objectIndex = ((state.objectIndex - 2) % #page.objects) + 1
                    openPresetPage()
                elseif args.action == 'nextObject' and #page.objects > 0 then
                    state.objectIndex = (state.objectIndex % #page.objects) + 1
                    openPresetPage()
                elseif args.action == 'compare' then
                    cleanupPreview(false)
                    NtMenu.hide(false)
                    state.compareOpen = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = 'presetCompareOpen', page = page, draft = state })
                end
            end,
        })
end
RegisterNUICallback('presetCompareReview', function(data, cb)
    local page = pages[pageIndex]
    if not page then cb({ ok = false }) return end
    local state = presetPageState(page)
    if type(data.draft) == 'table' then
        state.existingPreset = type(data.draft.existingPreset) == 'string' and data.draft.existingPreset or state.existingPreset
        state.replacePreset = data.draft.replacePreset == true
        state.checkedPoses = type(data.draft.checkedPoses) == 'table' and data.draft.checkedPoses or state.checkedPoses
        state.checkedObjects = type(data.draft.checkedObjects) == 'table' and data.draft.checkedObjects or state.checkedObjects
    end
    state.compareOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'presetCompareClose' })
    openPresetPage()
    cb({ ok = true })
end)

RegisterNUICallback('presetCompareApply', function(data, cb)
    local page = pages[pageIndex]
    if not page then cb({ ok = false }) return end
    local existingName = type(data.existingPreset) == 'string' and data.existingPreset or nil
    local result = lib.callback.await('nt_actions:server:submitPresetCompare', false,
        page.candidateName, existingName, data.replacePreset == true,
        type(data.checkedPoses) == 'table' and data.checkedPoses or {},
        type(data.checkedObjects) == 'table' and data.checkedObjects or {})
    if type(result) ~= 'table' then cb({ ok = false, error = 'The comparison could not be applied.' }) return end
    pages = result.pages or {}
    presetStates[page.key] = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'presetCompareClose' })
    cb({ ok = true })
    if #pages == 0 then endReview(true); notify('Preset review is complete.', 'success') return end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    openPresetPage()
end)
local function openReviewEntry()
    local status = lib.callback.await('nt_actions:server:reviewStatus', false) or {}
    if not status.authorized then notify('You do not have review permission.', 'error') return end
    local options = {
        {
            label = 'Cleanup Preset Review Data',
            description = ('%d presets / %d items'):format(status.presets or 0, status.items or 0),
            disabled = status.busy == true or not status.hasData,
            args = { action = 'cleanup' },
        },
        {
            label = 'Start Preset Review',
            description = status.clean and 'Preset review data is clean and ready.' or 'Cleanup must run first.',
            disabled = not status.clean or status.busy,
            args = { action = 'start' },
        },
    }
    NtMenu.open('Preset Upload Review', options, function(_, args)
        if args.action == 'cleanup' then
            local result = lib.callback.await('nt_actions:server:cleanupReview', false)
            if type(result) ~= 'table' then notify('Preset review cleanup failed.', 'error') return end
            notify(('%d invalid records removed; %d presets and %d items remain.'):format(
                result.removed or 0, result.presets or 0, result.items or 0), 'success')
            NtMenu.hide(false)
            openReviewEntry()
        elseif args.action == 'start' then
            local result = lib.callback.await('nt_actions:server:startPresetReview', false)
            if type(result) ~= 'table' or result.busy or result.needsCleanup then
                notify(result and result.busy and 'Another admin is reviewing this batch.' or 'Cleanup must run first.', 'error')
                return
            end
            pages = result.pages or {}
            if #pages == 0 then notify('There are no presets left to review.', 'inform') return end
            reviewOrigin = pedTransform()
            reviewActive = true
            pageIndex, checked, presetStates = 1, {}, {}
            openPresetPage()
        end
    end)
end
function NtReview.open()
    openReviewEntry()
end

RegisterCommand('poseReview', function()
    if reviewActive then
        notify('A pose review is already active.', 'error')
        return
    end
    if NtMenu.isOpen() then NtMenu.hide(true) end
    NtReview.open()
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if reviewActive then cleanupPreview(true) end
end)
