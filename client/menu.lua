local lastOpenAt = 0
poseMenuBlockedUntil = poseMenuBlockedUntil or 0

local function openPressed()
    if not Citizen.InvokeNative(0x580417101DDB492F, 0, Config.StartKey) then return false end
    local now = GetGameTimer()
    if now - lastOpenAt <= 300 then return false end
    lastOpenAt = now
    return true
end

local function handleOpenPress()
    if inPose ~= true then return end
    if not cachedPoseObject or not DoesEntityExist(cachedPoseObject) then
        inPose = false
        cachedPoseObject = nil
        return
    end
    if GetGameTimer() < poseMenuBlockedUntil then return end
    if NtMenu.isOpen() then
        NtMenu.hide(true)
        return
    end
    TriggerEvent('nt_actions:client:openCachedPoseList')
end

CreateThread(function()
    while true do
        Wait(4)
        if openPressed() then handleOpenPress() end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and NtMenu.isOpen() then
        NtMenu.hide(false)
    end
end)
