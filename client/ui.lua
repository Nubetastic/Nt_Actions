NtMenu = NtMenu or {}

local currentMenu
local menuStack = {}
local menuScaleKvp = 'nt_actions:menu_scale'
local scaleConfig = Config.MenuScale or {}
local scaleMin = tonumber(scaleConfig.Min) or 0.75
local scaleMax = tonumber(scaleConfig.Max) or 1.25
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

local function sendMenu()
    if not currentMenu then return end
    local options = {}
    for index, option in ipairs(currentMenu.options or {}) do
        options[index] = {
            label = option.label or ('Option ' .. index),
            description = option.description,
            disabled = option.disabled == true or not option.args,
        }
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'navOpen',
        title = currentMenu.title or 'Menu',
        options = options,
        canGoBack = #menuStack > 0,
        showScale = currentMenu.showScale == true,
        scale = menuScale,
        scaleMin = scaleMin,
        scaleMax = scaleMax,
        scaleStep = scaleStep,
    })
    TriggerEvent('nt_actions:client:setMenuOpen', true)
end

function NtMenu.open(title, options, callback, onClose, settings)
    if currentMenu then menuStack[#menuStack + 1] = currentMenu end
    currentMenu = {
        title = title,
        options = options or {},
        callback = callback,
        onClose = onClose,
        showScale = settings and settings.showScale == true,
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

RegisterNUICallback('navBack', function(_, cb)
    if #menuStack == 0 then
        NtMenu.hide(true)
    else
        currentMenu = table.remove(menuStack)
        sendMenu()
    end
    cb({ ok = true })
end)

RegisterNUICallback('navClose', function(_, cb)
    NtMenu.hide(true)
    cb({ ok = true })
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
