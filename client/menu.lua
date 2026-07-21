local lastOpenAt = 0
poseMenuBlockedUntil = poseMenuBlockedUntil or 0

local function openPressed()
    if not Citizen.InvokeNative(0x580417101DDB492F, 0, Config.StartKey) then return false end
    local now = GetGameTimer()
    if now - lastOpenAt <= 300 then return false end
    lastOpenAt = now
    return true
end

local function utilityOptions()
    local options = {}
    for _, button in ipairs(Config.MainMenuButtons or {}) do
        local hasAnimationEvent = type(Config.EmotesEvent) == 'string' and Config.EmotesEvent:match('%S') ~= nil
        if button.action ~= 'event_anim' or hasAnimationEvent then
            options[#options + 1] = {
                label = button.label,
                description = button.description,
                args = { action = button.action },
            }
        end
    end
    return options
end

local function openUtilityMenu()
    NtMenu.open('Actions', utilityOptions(), function(_, args)
        NtMenu.hide(false)
        if args.action == 'guntwirl' then
            TriggerEvent('ricx_guntwirl:toggleTwirl')
        elseif args.action == 'event_anim' then
            TriggerServerEvent(Config.EmotesEvent)
        end
    end)
end

CreateThread(function()
    while true do
        Wait(4)
        if openPressed() then
            if GetGameTimer() < poseMenuBlockedUntil then
                -- Add Pose is transitioning from the pose list into the offset editor.
            elseif NtMenu.isOpen() then
                NtMenu.hide(false)
            elseif inPose and cachedPoseObject and DoesEntityExist(cachedPoseObject) then
                TriggerEvent('nt_actions:client:openCachedPoseList')
            else
                openUtilityMenu()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and NtMenu.isOpen() then
        NtMenu.hide(false)
    end
end)
