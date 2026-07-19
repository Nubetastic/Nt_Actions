local resourceName = GetCurrentResourceName()
local cacheFile = ConfigTarget.CacheFile or 'object_offsets.json'
local offsets = {}

local function loadOffsets()
    local contents = LoadResourceFile(resourceName, cacheFile)
    if not contents or contents == '' then return end
    local ok, decoded = pcall(json.decode, contents)
    if ok and type(decoded) == 'table' then
        offsets = decoded
    else
        print(('[%s] Could not decode %s; starting with an empty object-offset cache.'):format(resourceName, cacheFile))
    end
end

local function validGroup(groupName)
    return type(groupName) == 'string'
        and ConfigGroups
        and ConfigGroups.Scenario
        and ConfigGroups.Scenario[groupName] ~= nil
end

local function normaliseOffset(value)
    if type(value) ~= 'table' then return end
    local maxOffset = tonumber(ConfigTarget.MaxOffset) or 3.0
    local x, y, z, heading = tonumber(value.x), tonumber(value.y), tonumber(value.z), tonumber(value.heading)
    if not x or not y or not z or not heading then return end
    if x ~= x or y ~= y or z ~= z or heading ~= heading then return end
    if math.abs(x) > maxOffset or math.abs(y) > maxOffset or math.abs(z) > maxOffset then return end
    return { x = x, y = y, z = z, heading = heading % 360.0 }
end

loadOffsets()

lib.callback.register('nt_actions:server:getObjectOffset', function(_, model, groupName)
    if type(model) ~= 'number' or not validGroup(groupName) then return nil end
    local modelCache = offsets[tostring(model)]
    local saved = modelCache and modelCache[groupName]
    if type(saved) ~= 'table' then return nil end
    return normaliseOffset(saved)
end)

RegisterNetEvent('nt_actions:server:saveObjectOffset', function(model, groupName, value)
    if type(model) ~= 'number' or not validGroup(groupName) then return end
    local clean = normaliseOffset(value)
    if not clean then return end

    local modelKey = tostring(model)
    offsets[modelKey] = offsets[modelKey] or {}
    clean.model = model
    clean.group = groupName
    offsets[modelKey][groupName] = clean

    local encoded = json.encode(offsets, { indent = true })
    if not SaveResourceFile(resourceName, cacheFile, encoded, -1) then
        print(('[%s] Failed to save object offset cache to %s.'):format(resourceName, cacheFile))
    end
end)
