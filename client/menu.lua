-- Unified Scenario Menu (U key) - ox_lib
-- Based on ScenarioMenu.md: Nearby menu when idle; Group switch menu when in grouped scenario; fallback to Nearby otherwise

-- DataView (minimal) for reading scenario point buffers
local _strblob = string.blob or function(length)
    return string.rep("\0", math.max(40 + 1, length))
end

DataView = {
    EndBig = ">",
    EndLittle = "<",
    Types = {
        Int32 = { code = "i4", size = 4 },
    },
}
DataView.__index = DataView
local function _ib(o, l, t) return ((t.size < 0 and true) or (o + (t.size - 1) <= l)) end
local function _ef(big) return (big and DataView.EndBig) or DataView.EndLittle end
local SetFixed = nil
function DataView.ArrayBuffer(length)
    return setmetatable({ offset = 1, length = length, blob = _strblob(length) }, DataView)
end
function DataView:Buffer() return self.blob end
for label,datatype in pairs(DataView.Types) do
    DataView["Get" .. label] = function(self, offset, endian)
        local o = self.offset + offset
        if _ib(o, self.length, datatype) then
            local v,_ = string.unpack(_ef(endian) .. datatype.code, self.blob, o)
            return v
        end
        return nil
    end
end

-- Global cached state
CachedGroupKey = CachedGroupKey or nil            -- string key for ConfigGroups.Scenario
CachedAnchor = CachedAnchor or nil                -- {x,y,z,h}
CachedTempScenarioPointId = CachedTempScenarioPointId or nil -- temp point id created for group switching
BaselineObjectSet = BaselineObjectSet or nil      -- set of CObject handles before starting initial scenario
inTempScenario = inTempScenario or false          -- true when current run was started via temp point
menuList = menuList or nil
CachedScenarioPointId = CachedScenarioPointId or nil -- scenario point id for unstuck feature
CachedPlayerOffset = CachedPlayerOffset or nil    -- {x,y,z} offset from scenario point

-- Menu open state
local isMenuOpen = false

-- Debounce U key
local lastOpenTs = 0
local function isOpenPressed()
    if Citizen.InvokeNative(0x580417101DDB492F, 0, Config.StartKey) then
        local now = GetGameTimer()
        if now - lastOpenTs > 300 then
            lastOpenTs = now
            return true
        end
    end
    return false
end

-- Natives wrappers
local function GetScenarioPointCoords(id, p1)
    return Citizen.InvokeNative(0xA8452DD321607029, id, p1, Citizen.ResultAsVector())
end
local function GetScenarioPointType(id)
    return Citizen.InvokeNative(0xA92450B5AE687AAF, id)
end
local function CreateScenarioPoint(hash, x, y, z, h)
    return Citizen.InvokeNative(0x94B745CE41DB58A1, hash, x, y, z, h or 0.0, 0.0, 0.0, true)
end
local function DeleteScenarioPoint(id)
    return Citizen.InvokeNative(0x81948DAE, id)
end

local function _CanPedUseScenarioPoint(ped, pointId)
    local f = rawget(_G, "_CAN_PED_USE_SCENARIO_POINT") or rawget(_G, "CanPedUseScenarioPoint")
    if f then
        local ok, res = pcall(f, ped, pointId)
        if ok then return res end
    end
    return true
end

local function TaskUseScenarioPoint(ped, pointId, scenarioName, p3, p4, p5, p6, p7)
    return Citizen.InvokeNative(0xCCDAE6324B6A821C, ped, pointId, scenarioName, p3 or 0.0, p4 or false, p5 or false, p6 or false, p7 or false)
end

local function TaskStartScenarioAtPositionHash(ped, scenarioHash, x, y, z, heading, duration, p7, p8)
    return Citizen.InvokeNative(0x4D1F61FC34AF3CD1, ped, scenarioHash, x, y, z, heading or 0.0, duration or -1, p7 or false, p8 or true)
end

-- Quick lookup: scenario hash -> {name,label}
local ScenarioHashToDef = {}
local function BuildScenarioHashIndex()
    ScenarioHashToDef = {}
    for _, v in ipairs(Config.Scenarios or {}) do
        local name = v[1]
        local label = (v[2] and v[2] ~= "") and v[2] or v[1]
        ScenarioHashToDef[GetHashKey(name)] = {name=name, label=label}
    end
end
BuildScenarioHashIndex()

-- Find which ConfigGroups.Scenario group a scenario belongs to
local function FindGroupKeyForScenario(scnName)
    if not (ConfigGroups and ConfigGroups.Scenario) then return nil end
    if ConfigGroups.Scenario[scnName] ~= nil then return scnName end
    for key, groupData in pairs(ConfigGroups.Scenario) do
        if groupData.Scenarios then
            for categoryName, scenarios in pairs(groupData.Scenarios) do
                for _, entry in ipairs(scenarios) do
                    if entry[1] == scnName then return key end
                end
            end
        else
            for _, entry in ipairs(groupData) do
                if entry[1] == scnName then return key end
            end
        end
    end
    return nil
end

-- Get gender lock for a scenario (returns "male", "female", or nil)
local function GetScenarioGenderLock(scenarioName)
    if not (ConfigGroups and ConfigGroups.Scenario) then return nil end
    for groupName, groupData in pairs(ConfigGroups.Scenario) do
        if groupData.Scenarios then
            for categoryName, scenarios in pairs(groupData.Scenarios) do
                for _, entry in ipairs(scenarios) do
                    if entry[1] == scenarioName then
                        local genderLock = entry[2]
                        return (genderLock and genderLock ~= "") and genderLock or nil
                    end
                end
            end
        else
            for _, entry in ipairs(groupData) do
                if entry[1] == scenarioName then
                    local genderLock = entry[2]
                    return (genderLock and genderLock ~= "") and genderLock or nil
                end
            end
        end
    end
    return nil
end

-- Check if scenario is compatible with player gender
local function IsScenarioGenderCompatible(scenarioName, ped)
    local genderLock = GetScenarioGenderLock(scenarioName)
    if not genderLock then return true end
    
    local isMale = IsPedMale(ped)
    if genderLock == "male" then
        return isMale
    elseif genderLock == "female" then
        return not isMale
    end
    return true
end

-- Label helper for group entries (display-only trimming)
local function GroupEntryDisplayLabel(groupKey, entry, truncatePatterns)
    local name = entry[1]
    local label = entry[2]
    -- Skip gender locks ("male", "female") and empty strings, only use actual labels
    if label and label ~= "" and label ~= "male" and label ~= "female" then return label end
    
    -- Do not trim the group root itself
    if name == groupKey then return name end
    
    -- Try to apply truncate patterns
    if truncatePatterns then
        for _, pattern in ipairs(truncatePatterns) do
            if name:sub(1, #pattern) == pattern then
                return name:sub(#pattern + 1)
            end
        end
    end
    
    -- Generic trim: if name starts with "<groupKey>_", display as "_" .. remainder
    local prefix = tostring(groupKey) .. "_"
    if name and name:sub(1, #prefix) == prefix then
        return "_" .. name:sub(#prefix + 1)
    end
    -- Fallback
    return name
end

local function ForceExitScenario(ped)
    SetPedShouldPlayNormalScenarioExit(ped)
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    Wait(3000)
    SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
end

local function PostScenarioCleanup()
    -- reset group/anchor/baseline
    CachedGroupKey = nil
    CachedCategoryKey = nil
    CachedAnchor = nil
    BaselineObjectSet = nil
    inTempScenario = false
    CachedScenarioPointId = nil
    CachedPlayerOffset = nil
end

-- Scan nearby scenario points and build menu element list
local function CollectNearbyScenarioElements(radius)
    local elements = {}
    local DataStruct = DataView.ArrayBuffer(256 * 4)
    local ped = PlayerPedId()
    local found = Citizen.InvokeNative(0x345EC3B7EBDE1CB5, GetEntityCoords(ped), radius or 1.5, DataStruct:Buffer(), 16)
    if not found or found == false or found <= 0 then return elements end

    local idx = 0
    for i = 1, found, 1 do
        local pointId = DataStruct:GetInt32(8 * i)
        if not CachedTempScenarioPointId or pointId ~= CachedTempScenarioPointId then
            local hash = GetScenarioPointType(pointId)
            local def = ScenarioHashToDef[hash]
            if def and _CanPedUseScenarioPoint(ped, pointId) and IsScenarioGenderCompatible(def.name, ped) then
                idx = idx + 1
                elements[idx] = { label = def.label, value = "start", pointId = pointId, scenarioName = def.name }
            end
        end
    end
    return elements
end

local function BuildFirstMenu()
    return {
        { label = "Nearest Task", args = { action = 'nearest' } },
        { label = "On Point", args = { action = 'on_point' } },
        { label = "Do Action", args = { action = 'do_action' } },
        { label = "GunTwirl", args = { action = 'guntwirl' } },
        { label = Config.EmotesButton, args = { action = 'event_anim' } },
    }
end

local function BuildEmotesMenu()
    if not (ConfigEmotes and ConfigEmotes.Emotes) then return {} end

    local emotesData = ConfigEmotes.Emotes
    local options = {}

    if emotesData.Groups then
        for groupName, emotes in pairs(emotesData.Groups) do
            options[#options+1] = {
                label = groupName,
                args = {
                    action = 'select_emotes_category',
                    categoryName = groupName
                }
            }
        end
    end

    return options
end

local function BuildEmoteCategoryMenu(categoryName)
    if not (ConfigEmotes and ConfigEmotes.Emotes) then return {} end

    local emotesData = ConfigEmotes.Emotes
    local options = {}

    if emotesData.Groups and emotesData.Groups[categoryName] then
        local emotes = emotesData.Groups[categoryName]
        for _, entry in ipairs(emotes) do
            local emoteKey = entry[1]
            local emoteLabel = entry[2]
            
            options[#options+1] = {
                label = emoteLabel,
                args = {
                    action = 'play_emote',
                    emoteKey = emoteKey
                }
            }
        end
    end

    return options
end

local function BuildActionMenu(actionType)
    local options = {}
    
    local near = CollectNearbyScenarioElements(1.25)
    if #near == 0 then
        options[#options+1] = { label = "No nearby scenarios", args = { action = 'noop' } }
    else
        for i=1,#near do
            local label = near[i].label
            options[#options+1] = {
                label = label,
                args = {
                    action = 'start',
                    type = actionType,
                    pointId = near[i].pointId,
                    scenarioName = near[i].scenarioName
                }
            }
        end
    end

    return options
end

local function UseNearestScenario()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TaskUseNearestScenarioToCoord(ped, coords, 1.5, 1, false, false, false, false)
    Citizen.Wait(2000)
    local newcoords = GetEntityCoords(ped)
    if coords == newcoords then
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)
        SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
    else
        local DataStruct = DataView.ArrayBuffer(256 * 4)
        local found = Citizen.InvokeNative(0x345EC3B7EBDE1CB5, GetEntityCoords(ped), 1.5, DataStruct:Buffer(), 16)
        if found and found > 0 then
            local pointId = DataStruct:GetInt32(8)
            if pointId then
                local sx, sy, sz = table.unpack(GetScenarioPointCoords(pointId, true))
                sx, sy, sz = sx or 0.0, sy or 0.0, sz or 0.0
                local px, py, pz = table.unpack(GetEntityCoords(ped))
                CachedScenarioPointId = pointId
                CachedPlayerOffset = { x = px - sx, y = py - sy, z = pz - sz }
            end
        end
    end
end

local CachedCategoryKey = nil

local function BuildGroupMenu()
    if not CachedGroupKey then return {} end
    if not (ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[CachedGroupKey]) then return {} end

    local ped = PlayerPedId()
    local groupData = ConfigGroups.Scenario[CachedGroupKey]
    local options = {}

    if groupData.Scenarios then
        for categoryName, scenarios in pairs(groupData.Scenarios) do
            local hasCompatibleScenario = false
            for _, entry in ipairs(scenarios) do
                if IsScenarioGenderCompatible(entry[1], ped) then
                    hasCompatibleScenario = true
                    break
                end
            end
            if hasCompatibleScenario then
                options[#options+1] = {
                    label = categoryName,
                    args = {
                        action = 'select_category',
                        categoryName = categoryName
                    }
                }
            end
        end
    else
        for _, entry in ipairs(groupData) do
            if IsScenarioGenderCompatible(entry[1], ped) then
                local label = GroupEntryDisplayLabel(CachedGroupKey, entry, groupData.truncate)
                options[#options+1] = {
                    label = label,
                    args = {
                        action = 'switch_pose',
                        scenarioName = entry[1]
                    }
                }
            end
        end
    end

    return options
end

local function BuildCategoryMenu(categoryName)
    if not CachedGroupKey or not categoryName then return {} end
    if not (ConfigGroups and ConfigGroups.Scenario and ConfigGroups.Scenario[CachedGroupKey]) then return {} end

    local ped = PlayerPedId()
    local groupData = ConfigGroups.Scenario[CachedGroupKey]
    local options = {}

    if groupData.Scenarios and groupData.Scenarios[categoryName] then
        local scenarios = groupData.Scenarios[categoryName]
        for _, entry in ipairs(scenarios) do
            if IsScenarioGenderCompatible(entry[1], ped) then
                local label = GroupEntryDisplayLabel(CachedGroupKey, entry, groupData.truncate)
                options[#options+1] = {
                    label = label,
                    args = {
                        action = 'switch_pose',
                        scenarioName = entry[1]
                    }
                }
            end
        end
    end

    return options
end

local function OpenFirstMenu()
    exports.ox_lib:registerMenu({
        id = 'scenario_first',
        title = 'Scenarios',
        position = 'top-right',
        options = BuildFirstMenu(),
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'nearest' then
            local nearby = CollectNearbyScenarioElements(1.5)
            if #nearby == 0 then
                return
            end
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            UseNearestScenario()
        elseif args.action == 'do_action' then
            OpenActionMenu('do_action')
        elseif args.action == 'on_point' then
            OpenActionMenu('on_point')
        elseif args.action == 'guntwirl' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            TriggerEvent('ricx_guntwirl:toggleTwirl')
        elseif args.action == 'event_anim' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            TriggerServerEvent(Config.EmotesEvent)
        end
    end)

    exports.ox_lib:showMenu('scenario_first')
    isMenuOpen = true
end



function OpenActionMenu(actionType)
    exports.ox_lib:registerMenu({
        id = 'scenario_action',
        title = actionType == 'nearest' and 'Nearest Task' or (actionType == 'do_action' and 'Do Action' or 'On Point'),
        position = 'top-right',
        options = BuildActionMenu(actionType),
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'start' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false

            local ped = PlayerPedId()
            local defName = args.scenarioName
            local gk = FindGroupKeyForScenario(defName)
            if gk then
                CachedGroupKey = gk
                CachedAnchor = nil
            else
                CachedGroupKey = nil
                CachedAnchor = nil
            end
            inTempScenario = false

            local sx, sy, sz = table.unpack(GetScenarioPointCoords(args.pointId, true))
            local sh = (GetScenarioPointHeading and GetScenarioPointHeading(args.pointId, true)) or 0
            sx, sy, sz = sx or 0.0, sy or 0.0, sz or 0.0
            sh = sh or 0.0

            local px, py, pz = table.unpack(GetEntityCoords(ped))
            CachedScenarioPointId = args.pointId
            CachedPlayerOffset = { x = px - sx, y = py - sy, z = pz - sz }

            Citizen.Wait(200)
            if args.type == 'do_action' then
                TaskStartScenarioAtPositionHash(ped, GetHashKey(args.scenarioName), sx, sy, sz, sh, 0, false, true)
            else
                TaskUseScenarioPoint(ped, args.pointId, args.scenarioName, 0.0, false, false, false, false)
            end
        elseif args.action == 'noop' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
        end
    end)

    exports.ox_lib:showMenu('scenario_action')
end

function OpenPoseMenu()
    local options = BuildGroupMenu()

    if #options == 0 then
        options = { { label = "No poses available", args = { action = 'noop' } } }
    end
    
    if CachedScenarioPointId and CachedPlayerOffset then
        table.insert(options, { label = "Unstuck", args = { action = 'unstuck' } })
    end
    table.insert(options, { label = "Leave Scenario", args = { action = 'finish' } })

    exports.ox_lib:registerMenu({
        id = 'scenario_pose',
        title = 'Change Pose',
        position = 'top-right',
        options = options,
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'select_category' then
            CachedCategoryKey = args.categoryName
            OpenCategoryMenu()
        elseif args.action == 'switch_pose' then
            local ped = PlayerPedId()
            local px, py, pz = table.unpack(GetEntityCoords(ped))
            local hdg = GetEntityHeading(ped)
            local h = GetHashKey(args.scenarioName)
            ClearPedTasksImmediately(ped)
            Citizen.Wait(50)
            TaskStartScenarioAtPositionHash(ped, h, px, py, pz, hdg, 0, false, true)
            inTempScenario = false
        elseif args.action == 'unstuck' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            if CachedScenarioPointId and CachedPlayerOffset then
                local ped = PlayerPedId()
                local sx, sy, sz = table.unpack(GetScenarioPointCoords(CachedScenarioPointId, true))
                sx, sy, sz = sx or 0.0, sy or 0.0, sz or 0.0
                local targetX = sx + CachedPlayerOffset.x
                local targetY = sy + CachedPlayerOffset.y
                local targetZ = sz + CachedPlayerOffset.z
                SetEntityCoords(ped, targetX, targetY, targetZ, false, false, false, false)
                ClearPedTasksImmediately(ped)
            end
        elseif args.action == 'finish' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            local ped = PlayerPedId()
            ForceExitScenario(ped)
            Citizen.Wait(1000)
            menuList = nil
            PostScenarioCleanup()
        elseif args.action == 'noop' then
            return
        end
    end)

    exports.ox_lib:showMenu('scenario_pose')
end

function OpenCategoryMenu()
    local options = BuildCategoryMenu(CachedCategoryKey)

    if #options == 0 then
        options = { { label = "No poses available", args = { action = 'noop' } } }
    end

    exports.ox_lib:registerMenu({
        id = 'scenario_category',
        title = CachedCategoryKey,
        position = 'top-right',
        options = options,
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'switch_pose' then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local hdg = GetEntityHeading(ped)
            local h = GetHashKey(args.scenarioName)
            ClearPedTasksImmediately(ped)
            Citizen.Wait(50)
            TaskStartScenarioAtPositionHash(ped, h, coords, hdg, 0, false, true)
            inTempScenario = false
        elseif args.action == 'noop' then
            return
        end
    end)

    exports.ox_lib:showMenu('scenario_category')
end

function OpenEmotesMenu()
    local options = BuildEmotesMenu()

    if #options == 0 then
        options = { { label = "No emotes available", args = { action = 'noop' } } }
    end
    table.insert(options, { label = "Stop Emote", args = { action = 'stop_emote' } })

    exports.ox_lib:registerMenu({
        id = 'scenario_emotes',
        title = 'Emotes',
        position = 'top-right',
        options = options,
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'select_emotes_category' then
            CachedCategoryKey = args.categoryName
            OpenEmoteCategoryMenu()
        elseif args.action == 'stop_emote' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            ExecuteCommand('e')
            menuList = nil
        elseif args.action == 'noop' then
            return
        end
    end)

    exports.ox_lib:showMenu('scenario_emotes')
end

function OpenEmoteCategoryMenu()
    local options = BuildEmoteCategoryMenu(CachedCategoryKey)

    if #options == 0 then
        options = { { label = "No emotes available", args = { action = 'noop' } } }
    end

    exports.ox_lib:registerMenu({
        id = 'scenario_emotes_category',
        title = CachedCategoryKey,
        position = 'top-right',
        options = options,
        canClose = true
    }, function(selected, scrollIndex, args)
        if args.action == 'play_emote' then
            exports.ox_lib:hideMenu()
            isMenuOpen = false
            ExecuteCommand('e ' .. args.emoteKey)
            menuList = nil
        elseif args.action == 'noop' then
            return
        end
    end)

    exports.ox_lib:showMenu('scenario_emotes_category')
end

local function OpenMenuHandler()
    local ped = PlayerPedId()
    if IsPedActiveInScenario(ped) then
        OpenPoseMenu()
    elseif menuList == "Emotes" then
        OpenEmotesMenu()
    else
        OpenFirstMenu()
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(4)
        if isOpenPressed() then
            if isMenuOpen then
                exports.ox_lib:hideMenu()
                isMenuOpen = false
            else
                OpenMenuHandler()
            end
        end
    end
end)

-- Safety tick: if temp scenario ended unexpectedly, cleanup
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        if inTempScenario and not IsPedActiveInScenario(PlayerPedId()) then
            PostScenarioCleanup()
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    exports.ox_lib:hideMenu()
    isMenuOpen = false
    if IsPedActiveInScenario(PlayerPedId()) then
        SetPedShouldPlayNormalScenarioExit(PlayerPedId())
    end
    PostScenarioCleanup()
end)