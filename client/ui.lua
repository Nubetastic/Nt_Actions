NtMenu = NtMenu or {}

local currentMenu
local menuStack = {}
local menuScaleKvp = 'nt_actions:menu_scale'
local scaleConfig = Config.MenuScale or {}
local scaleMin = tonumber(scaleConfig.Min) or 0.5
local scaleMax = tonumber(scaleConfig.Max) or 2.0
local scaleStep = tonumber(scaleConfig.Step) or 0.05
local defaultScale = tonumber(scaleConfig.Default) or 1.0
local menuScale = GetResourceKvpFloat(menuScaleKvp)

local function clampScale(value)
    return math.max(scaleMin, math.min(scaleMax, value))
end

if not menuScale or menuScale <= 0.0 then
    menuScale = clampScale(defaultScale)
else
    menuScale = clampScale(menuScale)
end

local function sendMenu(preserveScroll)
    if not currentMenu then return end
    local options = {}
    for index, option in ipairs(currentMenu.options or {}) do
        options[index] = {
            label = option.label or ('Option ' .. index),
            rightLabel = option.rightLabel,
            description = option.description,
            disabled = option.disabled == true or not option.args,
            deletable = option.deletable == true,
            restorable = option.restorable == true,
            coordinate = option.coordinate == true,
            checkable = option.checkable == true,
            checked = option.checked == true,
            tone = option.tone == 'success' and 'success' or option.tone == 'danger' and 'danger' or nil,
            section = option.section == true,
            gapBefore = option.gapBefore == true,
            coordBadge = tonumber(option.coordBadge),
        }
    end
    local footerActions = {}
    for index, action in ipairs(currentMenu.footerActions or {}) do
        footerActions[index] = {
            label = action.label or ('Action ' .. index),
            disabled = action.disabled == true or not action.args,
            danger = action.danger == true,
            wide = action.wide == true,
        }
    end
    local coordinates = {}
    if type(currentMenu.coordinateOptions) == 'table' then
        for index, option in ipairs(currentMenu.coordinateOptions) do
            coordinates[index] = {
                number = index,
                label = option.label or tostring(index),
                title = option.title,
                deletable = option.deletable == true,
                checkable = option.checkable == true,
                checked = option.checked == true,
                pointGroup = option.pointGroup,
            }
        end
    else
        for index in ipairs(currentMenu.coordinates or {}) do
            coordinates[index] = {
                number = index,
                label = tostring(index),
                deletable = currentMenu.coordinatesDeletable == true,
            }
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'navOpen',
        preserveScroll = preserveScroll == true,
        title = currentMenu.title or 'Menu',
        options = options,
        footerActions = footerActions,
        canGoBack = #menuStack > 0 and not currentMenu.hideBack,
        showScale = true,
        scale = menuScale,
        scaleMin = scaleMin,
        scaleMax = scaleMax,
        scaleStep = scaleStep,
        showMod = currentMenu.showMod,
        modActive = currentMenu.modActive,
        showReviewCamera = currentMenu.showReviewCamera,
        reviewCameraDistance = currentMenu.reviewCameraDistance,
        reviewCameraMin = currentMenu.reviewCameraMin,
        reviewCameraMax = currentMenu.reviewCameraMax,
        reviewCameraStep = currentMenu.reviewCameraStep,
        coordinates = coordinates,
        selectedCoordinate = currentMenu.selectedCoordinate,
        showGroupEdit = currentMenu.showGroupEdit,
        showPreset = currentMenu.showPreset,
        presetLabel = currentMenu.presetLabel,
    })
    TriggerEvent('nt_actions:client:setMenuOpen', true)
end

function NtMenu.open(title, options, callback, onClose, settings)
    settings = settings or {}
    if currentMenu then menuStack[#menuStack + 1] = currentMenu end
    currentMenu = {
        title = title,
        options = options or {},
        callback = callback,
        onClose = onClose,
        onDelete = settings.onDelete,
        onRestore = settings.onRestore,
        footerActions = settings.footerActions or {},
        onFooter = settings.onFooter,
        showMod = settings.showMod == true,
        modActive = settings.modActive == true,
        onMod = settings.onMod,
        onCheck = settings.onCheck,
        showReviewCamera = settings.showReviewCamera == true,
        reviewCameraDistance = settings.reviewCameraDistance,
        reviewCameraMin = settings.reviewCameraMin,
        reviewCameraMax = settings.reviewCameraMax,
        reviewCameraStep = settings.reviewCameraStep,
        onReviewZoom = settings.onReviewZoom,
        onCameraLook = settings.onCameraLook,
        hideBack = settings.hideBack == true,
        coordinates = settings.coordinates or {},
        coordinateOptions = settings.coordinateOptions,
        selectedCoordinate = tonumber(settings.selectedCoordinate) or 1,
        coordinatesDeletable = settings.coordinatesDeletable == true,
        onCoordinateSelect = settings.onCoordinateSelect,
        onCoordinateDelete = settings.onCoordinateDelete,
        onCoordinateCheck = settings.onCoordinateCheck,
        showGroupEdit = settings.showGroupEdit == true,
        onGroupEdit = settings.onGroupEdit,
        showPreset = settings.showPreset == true,
        presetLabel = settings.presetLabel,
        onPreset = settings.onPreset,
    }
    sendMenu()
end

function NtMenu.hide(runClose)
    local closing = currentMenu
    currentMenu = nil
    menuStack = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'navClose' })
    TriggerEvent('nt_actions:client:setMenuOpen', false)
    if runClose and closing and closing.onClose then closing.onClose() end
end

function NtMenu.isOpen()
    return currentMenu ~= nil
end

function NtMenu.getScale()
    return menuScale
end

function NtMenu.refresh(preserveScroll)
    sendMenu(preserveScroll)
end

function NtMenu.refreshFooter()
    if not currentMenu then return end
    local footerActions = {}
    for index, action in ipairs(currentMenu.footerActions or {}) do
        footerActions[index] = {
            label = action.label or ('Action ' .. index),
            disabled = action.disabled == true or not action.args,
            danger = action.danger == true,
            wide = action.wide == true,
        }
    end
    SendNUIMessage({ action = 'navFooterUpdate', footerActions = footerActions })
end

function NtMenu.back()
    if #menuStack == 0 then
        NtMenu.hide(true)
    else
        currentMenu = table.remove(menuStack)
        sendMenu()
    end
end

RegisterNUICallback('navSelect', function(data, cb)
    local menu = currentMenu
    local index = tonumber(data.index)
    local option = menu and index and menu.options[index]
    if not option or option.disabled or not option.args then
        cb({ ok = false })
        return
    end

    cb({ ok = true })
    if menu.callback then menu.callback(index, option.args) end
end)

RegisterNUICallback('navDelete', function(data, cb)
    local menu = currentMenu
    local index = tonumber(data.index)
    local option = menu and index and menu.options[index]
    if not option or option.deletable ~= true or not option.args or not menu.onDelete then
        cb({ ok = false })
        return
    end

    cb({ ok = true })
    menu.onDelete(index, option.args)
end)

RegisterNUICallback('navRestore', function(data, cb)
    local menu = currentMenu
    local index = tonumber(data.index)
    local option = menu and index and menu.options[index]
    if not option or option.restorable ~= true or not option.args or not menu.onRestore then
        cb({ ok = false })
        return
    end

    cb({ ok = true })
    menu.onRestore(index, option.args)
end)

RegisterNUICallback('navCheck', function(data, cb)
    local menu = currentMenu
    local index = tonumber(data.index)
    local option = menu and index and menu.options[index]
    if not option or option.checkable ~= true or not option.args or not menu.onCheck then
        cb({ ok = false })
        return
    end
    option.checked = data.checked == true
    cb({ ok = true })
    menu.onCheck(index, option.args, option.checked)
end)

RegisterNUICallback('navFooter', function(data, cb)
    local menu = currentMenu
    local index = tonumber(data.index)
    local action = menu and index and menu.footerActions[index]
    if not action or action.disabled or not action.args or not menu.onFooter then
        cb({ ok = false })
        return
    end

    cb({ ok = true })
    menu.onFooter(index, action.args)
end)

RegisterNUICallback('navBack', function(_, cb)
    NtMenu.back()
    cb({ ok = true })
end)

RegisterNUICallback('navClose', function(_, cb)
    NtMenu.hide(true)
    cb({ ok = true })
end)

RegisterNUICallback('navMod', function(_, cb)
    local menu = currentMenu
    if not menu or menu.showMod ~= true or not menu.onMod then
        cb({ ok = false })
        return
    end
    cb({ ok = true })
    menu.onMod()
end)

RegisterNUICallback('navGroupEdit', function(_, cb)
    local menu = currentMenu
    if not menu or menu.showGroupEdit ~= true or not menu.onGroupEdit then
        cb({ ok = false })
        return
    end
    cb({ ok = true })
    menu.onGroupEdit()
end)
RegisterNUICallback('navPreset', function(_, cb)
    local menu = currentMenu
    if not menu or menu.showPreset ~= true or not menu.onPreset then cb({ ok = false }) return end
    cb({ ok = true })
    menu.onPreset()
end)
RegisterNUICallback('navCoordinateSelect', function(data, cb)
    local menu = currentMenu
    local coordNumber = tonumber(data.coordNumber)
    local coordinate = menu and coordNumber and (
        type(menu.coordinateOptions) == 'table' and menu.coordinateOptions[coordNumber]
            or menu.coordinates[coordNumber]
    )
    if not coordinate or not menu.onCoordinateSelect then
        cb({ ok = false })
        return
    end
    menu.selectedCoordinate = coordNumber
    cb({ ok = true })
    menu.onCoordinateSelect(coordNumber, type(coordinate) == 'table' and coordinate.args or nil)
end)

RegisterNUICallback('navCoordinateCheck', function(data, cb)
    local menu = currentMenu
    local coordNumber = tonumber(data.coordNumber)
    local coordinate = menu and type(menu.coordinateOptions) == 'table'
        and coordNumber and menu.coordinateOptions[coordNumber]
    if not coordinate or coordinate.checkable ~= true or not coordinate.args or not menu.onCoordinateCheck then
        cb({ ok = false })
        return
    end
    coordinate.checked = data.checked == true
    cb({ ok = true })
    menu.onCoordinateCheck(coordNumber, coordinate.args, coordinate.checked)
end)

RegisterNUICallback('navCoordinateDelete', function(data, cb)
    local menu = currentMenu
    local coordNumber = tonumber(data.coordNumber)
    local coordinate = menu and coordNumber and (
        type(menu.coordinateOptions) == 'table' and menu.coordinateOptions[coordNumber]
            or menu.coordinates[coordNumber]
    )
    local deletable = type(coordinate) == 'table' and coordinate.deletable == true
        or menu and menu.coordinatesDeletable == true
    if not coordinate or not deletable or not menu.onCoordinateDelete then
        cb({ ok = false })
        return
    end
    cb({ ok = true })
    menu.onCoordinateDelete(coordNumber)
end)

RegisterNUICallback('navReviewZoom', function(data, cb)
    local menu = currentMenu
    if not menu or not menu.onReviewZoom then cb({ ok = false }) return end
    menu.onReviewZoom(tonumber(data.distance))
    cb({ ok = true })
end)

RegisterNUICallback('navCameraLook', function(_, cb)
    local menu = currentMenu
    if not menu or not menu.onCameraLook then cb({ ok = false }) return end
    cb({ ok = true })
    menu.onCameraLook()
end)

RegisterNUICallback('navScale', function(data, cb)
    local requestedScale = tonumber(data.scale)
    if not requestedScale then
        cb({ ok = false, scale = menuScale })
        return
    end

    menuScale = clampScale(requestedScale)
    SetResourceKvpFloat(menuScaleKvp, menuScale)
    cb({ ok = true, scale = menuScale })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if currentMenu then NtMenu.hide(false) end
end)
