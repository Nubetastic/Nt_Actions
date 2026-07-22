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
    pages, checked, pageIndex, reviewOrigin = {}, {}, 1, nil
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

local openPage

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

local function submitPage()
    local page = pages[pageIndex]
    if not page then return end
    local state = pageState(page)
    local approvedPoses, approvedCoords = {}, {}
    for id, value in pairs(state.poses) do if value == true then approvedPoses[#approvedPoses + 1] = id end end
    for id, value in pairs(state.coords) do if value == true then approvedCoords[#approvedCoords + 1] = id end end
    cleanupPreview(true)
    local result = lib.callback.await(
        'nt_actions:server:submitReviewGroup', false,
        page.key, approvedPoses, approvedCoords, reviewerGender())
    if type(result) ~= 'table' then
        notify('The review item could not be saved.', 'error')
        openPage()
        return
    end
    notify(('%d/%d poses and %d/%d points approved.'):format(
        result.posesMerged or 0,
        result.posesProcessed or 0,
        result.coordsMerged or 0,
        result.coordsProcessed or 0
    ), 'success')
    if result.waitingForGender then
        notify(('Poses remain for review with a %s ped.'):format(result.waitingForGender), 'inform')
    end
    pages = result.pages or {}
    checked[page.key] = nil
    if #pages == 0 then
        endReview(true)
        notify('Batch review is complete.', 'success')
        return
    end
    pageIndex = math.max(1, math.min(pageIndex, #pages))
    openPage()
end

local function approvePage()
    local page = pages[pageIndex]
    if not page then return end
    local state = pageState(page)

    local waitingGender
    for _, pose in ipairs(page.poses or {}) do
        if not poseCompatible(pose) then waitingGender = waitingGender or pose.gender end
    end
    local confirmationOptions = {
        {
            label = waitingGender
                and 'Warning: Unchecked compatible poses are removed; other-gender poses and pending points remain.'
                or 'Warning: Confirm decisions; unchecked poses and new coordinates will be removed.',
            disabled = true,
            tone = 'danger',
        },
        { label = 'Poses to be processed', disabled = true, section = true, gapBefore = true },
    }
    local firstPose = true
    for _, pose in ipairs(page.poses or {}) do
        if not pose.current and poseCompatible(pose) then
            local approved = state.poses[pose.id] == true
            confirmationOptions[#confirmationOptions + 1] = {
                label = NtActionsClient.poseLabel(pose.group, pose.scenario),
                description = approved and 'Will be approved' or 'Will be removed',
                disabled = true,
                tone = approved and 'success' or 'danger',
                gapBefore = firstPose,
            }
            firstPose = false
        end
    end
    if firstPose then
        confirmationOptions[#confirmationOptions + 1] = {
            label = 'No new poses', disabled = true, gapBefore = true,
        }
    end

    if waitingGender then
        confirmationOptions[#confirmationOptions + 1] = {
            label = 'Poses waiting for another gender', disabled = true, section = true, gapBefore = true,
        }
        for _, pose in ipairs(page.poses or {}) do
            if not poseCompatible(pose) then
                confirmationOptions[#confirmationOptions + 1] = {
                    label = NtActionsClient.poseLabel(pose.group, pose.scenario),
                    description = ('Preserved for a %s ped'):format(pose.gender),
                    rightLabel = genderLabel(pose.gender),
                    disabled = true,
                }
            end
        end
    end

    confirmationOptions[#confirmationOptions + 1] = {
        label = 'New coordinates to be processed', disabled = true, section = true, gapBefore = true,
    }
    if #(page.newCoords or {}) == 0 then
        confirmationOptions[#confirmationOptions + 1] = {
            label = 'No new coordinates', disabled = true, gapBefore = true,
        }
    else
        for index, coord in ipairs(page.newCoords) do
            local approved = state.coords[coord.id] == true
            confirmationOptions[#confirmationOptions + 1] = {
                label = ('New point N%d'):format(index),
                description = (approved and 'Will be approved - '
                    or waitingGender and 'Will remain pending - '
                    or 'Will be removed - ')
                    .. coordDescription(coord.offset),
                disabled = true,
                tone = approved and 'success' or not waitingGender and 'danger' or nil,
                gapBefore = index == 1,
            }
        end
    end

    NtMenu.open(
        'Confirm Approval',
        confirmationOptions,
        nil,
        function() endReview(false) end,
        {
            footerActions = {
                { label = 'Approve', args = { action = 'approve' } },
                { label = 'Back', args = { action = 'back' } },
            },
            hideBack = true,
            onFooter = function(_, args)
                if args.action == 'approve' then
                    NtMenu.hide(false)
                    submitPage()
                elseif args.action == 'back' then
                    NtMenu.back()
                end
            end,
        }
    )
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

openPage = function()
    local page = pages[pageIndex]
    if not page then endReview(true) return end
    NtMenu.hide(false)
    if not spawnReviewObject(page.item) then
        notify(('Model %s could not be spawned.'):format(page.item), 'error')
    end
    local state = pageState(page)
    local options = {}
    for _, pose in ipairs(page.poses or {}) do
        if not pose.current then
            local compatible = poseCompatible(pose)
            options[#options + 1] = {
                label = NtActionsClient.poseLabel(pose.group, pose.scenario),
                rightLabel = not compatible and genderLabel(pose.gender) or nil,
                description = not compatible and (pose.group .. ' - Requires a ' .. pose.gender .. ' ped')
                    or pose.group,
                disabled = not compatible,
                checkable = compatible,
                checked = compatible and state.poses[pose.id] == true,
                args = compatible and { pose = pose } or nil,
            }
        end
    end
    local coordinateOptions = {}
    for index, offset in ipairs(page.currentCoords or {}) do
        coordinateOptions[#coordinateOptions + 1] = {
            label = tostring(index),
            title = ('Current point %d - %s'):format(index, coordDescription(offset)),
            args = { offset = offset, current = true },
        }
    end
    for index, coord in ipairs(page.newCoords or {}) do
        coordinateOptions[#coordinateOptions + 1] = {
            label = ('N%d'):format(index),
            title = ('New point N%d - %s'):format(index, coordDescription(coord.offset)),
            checkable = true,
            checked = state.coords[coord.id] == true,
            args = { id = coord.id, offset = coord.offset },
        }
    end
    state.selectedCoordinate = math.max(1, math.min(
        #coordinateOptions,
        tonumber(state.selectedCoordinate) or 1
    ))
    local footer = {
        { label = 'Back', disabled = pageIndex <= 1, args = { action = 'back' } },
        { label = 'Next', disabled = pageIndex >= #pages, args = { action = 'next' } },
        { label = 'Approve', args = { action = 'approve' } },
    }
    NtMenu.open(
        ('Review %d/%d - Object %s'):format(pageIndex, #pages, page.item),
        options,
        function(_, args)
            local coordinate = coordinateOptions[state.selectedCoordinate]
            previewPose(args.pose, coordinate and coordinate.args.offset or nil)
        end,
        function() endReview(false) end,
        {
            footerActions = footer,
            coordinateOptions = coordinateOptions,
            selectedCoordinate = state.selectedCoordinate,
            showReviewCamera = true,
            reviewCameraDistance = cameraRadius,
            reviewCameraMin = tonumber(settings.CameraZoomMin) or 0.75,
            reviewCameraMax = tonumber(settings.CameraZoomMax) or 8.0,
            reviewCameraStep = tonumber(settings.CameraZoomStep) or 0.25,
            onReviewZoom = function(distance)
                local minimum = tonumber(settings.CameraZoomMin) or 0.75
                local maximum = tonumber(settings.CameraZoomMax) or 8.0
                cameraRadius = math.max(minimum, math.min(maximum, tonumber(distance) or cameraRadius))
                positionCamera()
            end,
            onCameraLook = beginCameraLook,
            onCheck = function(_, args, value)
                if not args.pose.current then state.poses[args.pose.id] = value == true end
            end,
            onCoordinateSelect = function(index)
                state.selectedCoordinate = index
            end,
            onCoordinateCheck = function(_, args, value)
                state.coords[args.id] = value == true
            end,
            onFooter = function(_, args)
                if args.action == 'back' then
                    pageIndex = pageIndex - 1
                    openPage()
                elseif args.action == 'next' then
                    pageIndex = pageIndex + 1
                    openPage()
                elseif args.action == 'approve' then
                    approvePage()
                end
            end,
        }
    )
end

local function openReviewEntry()
    local status = lib.callback.await('nt_actions:server:reviewStatus', false) or {}
    if not status.authorized then notify('You do not have review permission.', 'error') return end
    local options = {
        {
            label = 'Cleanup Review Data',
            description = ('%d items / %d poses / %d points'):format(
                status.items or 0, status.poses or 0, status.coords or 0),
            disabled = status.busy == true or not status.hasData,
            args = { action = 'cleanup' },
        },
        {
            label = 'Start Review',
            description = status.clean and 'Review data is clean and ready.' or 'Cleanup must run first.',
            disabled = not status.clean or status.busy,
            args = { action = 'start' },
        },
    }
    NtMenu.open('Upload Review', options, function(_, args)
        if args.action == 'cleanup' then
            local result = lib.callback.await('nt_actions:server:cleanupReview', false)
            if type(result) ~= 'table' then notify('Review cleanup failed.', 'error') return end
            notify(('%d records removed; %d remain.'):format(result.removed or 0, result.poses or 0), 'success')
            NtMenu.hide(false)
            openReviewEntry()
        elseif args.action == 'start' then
            local result = lib.callback.await('nt_actions:server:startReview', false)
            if type(result) ~= 'table' or result.busy or result.needsCleanup then
                notify(result and result.busy and 'Another admin is reviewing this batch.' or 'Cleanup must run first.', 'error')
                return
            end
            pages = result.pages or {}
            if #pages == 0 then notify('There are no poses left to review.', 'inform') return end
            reviewOrigin = pedTransform()
            reviewActive = true
            pageIndex, checked = 1, {}
            openPage()
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
