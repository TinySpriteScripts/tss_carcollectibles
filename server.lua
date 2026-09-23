local collectiblesById = {}
local setsById = {}
local collectionLocks = {}

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

for _, set in ipairs(CarCollectibleSets) do
    assert(type(set.id) == 'string' and set.id ~= '', 'tss_carcollectibles: every set needs an id')
    assert(type(set.locations) == 'table', ('tss_carcollectibles: set %s needs locations'):format(set.id))
    assert(not setsById[set.id], ('tss_carcollectibles: duplicate set id %s'):format(set.id))
    setsById[set.id] = set
    for index, coords in ipairs(set.locations) do
        local collectibleId = ('%s:%d'):format(set.id, index)
        assert(not collectiblesById[collectibleId], ('tss_carcollectibles: duplicate id %s'):format(collectibleId))
        collectiblesById[collectibleId] = {
            id = collectibleId,
            setId = set.id,
            coords = coords,
            reward = set.reward or {},
        }
    end
end

local function getCollected(source)
    local collected = exports.streetkings:ReadSaveData(source, 'carCollectibles.collected')
    return type(collected) == 'table' and collected or {}
end

lib.callback.register('tss_carcollectibles:getProgress', function(source)
    if not exports.streetkings:HasActiveSave(source) then
        return { ok = false, collected = {} }
    end
    return { ok = true, collected = getCollected(source) }
end)

lib.callback.register('tss_carcollectibles:collect', function(source, collectibleId)
    if collectionLocks[source] then return { ok = false, reason = 'busy' } end
    collectionLocks[source] = true

    local collectible = type(collectibleId) == 'string' and collectiblesById[collectibleId] or nil
    if not collectible or not exports.streetkings:HasActiveSave(source) then
        collectionLocks[source] = nil
        return { ok = false, reason = 'invalid' }
    end
    if exports.streetkings:GetPlayerGameState(source) ~= 'freeroam' then
        collectionLocks[source] = nil
        return { ok = false, reason = 'freeroam_only' }
    end

    local ped = GetPlayerPed(source)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        collectionLocks[source] = nil
        return { ok = false, reason = 'driver_required' }
    end
    if distance(GetEntityCoords(vehicle), collectible.coords) > CarCollectiblesConfig.collectDistance + 5.0 then
        collectionLocks[source] = nil
        return { ok = false, reason = 'too_far' }
    end

    local collected = getCollected(source)
    if collected[collectibleId] == true then
        collectionLocks[source] = nil
        return { ok = false, reason = 'already_collected' }
    end

    -- Save completion before paying so duplicate requests cannot award twice.
    collected[collectibleId] = true
    if not exports.streetkings:WriteSaveData(source, 'carCollectibles.collected', collected) then
        collectionLocks[source] = nil
        return { ok = false, reason = 'save_failed' }
    end

    local cash = math.max(0, math.floor(tonumber(collectible.reward.cash) or 0))
    local playerXp = math.max(0, math.floor(tonumber(collectible.reward.playerXp) or 0))
    if cash > 0 then exports.streetkings:AddPlayerCash(source, cash) end
    local xpResult = playerXp > 0 and exports.streetkings:AwardPlayerXp(source, playerXp) or nil

    collectionLocks[source] = nil
    return {
        ok = true,
        cash = cash,
        playerXp = xpResult and xpResult.xpGained or playerXp,
    }
end)

RegisterNetEvent('tss_carcollectibles:resetProgress', function(setId)
    local source = source
    if IsPlayerAceAllowed(source, 'command') ~= 1 then
        TriggerClientEvent('sayer_devtools:resetCollectiblesResult', source, false, 'Not allowed')
        return
    end
    if type(setId) ~= 'string' or not setsById[setId] then
        TriggerClientEvent('sayer_devtools:resetCollectiblesResult', source, false, 'Unknown collection ID')
        return
    end
    if not exports.streetkings:HasActiveSave(source) then
        TriggerClientEvent('sayer_devtools:resetCollectiblesResult', source, false, 'No active save')
        return
    end

    local collected = getCollected(source)
    local prefix = setId .. ':'
    local removed = 0
    for collectibleId in pairs(collected) do
        if type(collectibleId) == 'string' and collectibleId:sub(1, #prefix) == prefix then
            collected[collectibleId] = nil
            removed = removed + 1
        end
    end

    if not exports.streetkings:WriteSaveData(source, 'carCollectibles.collected', collected) then
        TriggerClientEvent('sayer_devtools:resetCollectiblesResult', source, false, 'Save update failed')
        return
    end

    TriggerClientEvent('tss_carcollectibles:progressReset', source, setId)
    TriggerClientEvent('sayer_devtools:resetCollectiblesResult',source,true,('Reset %s (%d collected)'):format(setId, removed))
end)

AddEventHandler('playerDropped', function()
    collectionLocks[source] = nil
end)
