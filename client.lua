local collectibles = {}
local spawned = {}
local loading = {}
local collected = {}
local pending = {}
local isFreeroam = false
local progressReady = false

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

for _, set in ipairs(CarCollectibleSets) do
    for index, coords in ipairs(set.locations) do
        collectibles[#collectibles + 1] = {
            id = ('%s:%d'):format(set.id, index),
            setId = set.id,
            name = set.name or 'Collectible',
            model = set.model,
            coords = coords,
            floatHeight = set.floatHeight or CarCollectiblesConfig.floatHeight,
            bobHeight = set.bobHeight or CarCollectiblesConfig.bobHeight,
            bobSpeed = set.bobSpeed or CarCollectiblesConfig.bobSpeed,
            rotationSpeed = set.rotationSpeed or CarCollectiblesConfig.rotationSpeed,
        }
    end
end

local function notify(title, kind)
    exports.streetkings:ShowNotification({ title = title, type = kind or 'info', duration = 3500 })
end

local function deleteSpawned(collectibleId)
    local entry = spawned[collectibleId]
    if not entry then return end
    if DoesEntityExist(entry.object) then DeleteEntity(entry.object) end
    SetModelAsNoLongerNeeded(entry.model)
    spawned[collectibleId] = nil
end

local function clearSpawned()
    local ids = {}
    for id in pairs(spawned) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do deleteSpawned(id) end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        print(('[tss_carcollectibles] Invalid model: %s'):format(tostring(model)))
        return nil
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then
        print(('[tss_carcollectibles] Timed out loading model: %s'):format(tostring(model)))
        return nil
    end
    return hash
end

local function spawnCollectible(item)
    if spawned[item.id] or loading[item.id] or collected[item.id] or pending[item.id] then return end
    loading[item.id] = true
    local hash = loadModel(item.model)
    if not hash or collected[item.id] or not isFreeroam then
        loading[item.id] = nil
        return
    end
    local z = item.coords.z + item.floatHeight
    local object = CreateObjectNoOffset(hash, item.coords.x, item.coords.y, z, false, false, false)
    if object == 0 then
        SetModelAsNoLongerNeeded(hash)
        loading[item.id] = nil
        return
    end
    SetEntityAsMissionEntity(object, true, true)
    SetEntityCollision(object, false, false)
    SetEntityInvincible(object, true)
    FreezeEntityPosition(object, true)
    SetEntityCanBeDamaged(object, false)
    spawned[item.id] = {
        object = object,
        model = hash,
        heading = 0.0,
        phase = (joaat(item.id) % 628) / 100.0,
    }
    loading[item.id] = nil
end

local function collect(item)
    if pending[item.id] or collected[item.id] then return end
    pending[item.id] = true
    local result = lib.callback.await('tss_carcollectibles:collect', false, item.id)
    pending[item.id] = nil
    if not result or not result.ok then
        if result and result.reason == 'already_collected' then
            collected[item.id] = true
            deleteSpawned(item.id)
        end
        return
    end

    collected[item.id] = true
    deleteSpawned(item.id)
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    local parts = { item.name .. ' collected' }
    if result.cash and result.cash > 0 then parts[#parts + 1] = ('$%d'):format(result.cash) end
    if result.playerXp and result.playerXp > 0 then parts[#parts + 1] = ('+%d XP'):format(result.playerXp) end
    notify(table.concat(parts, ' | '), 'success')
end

local function loadProgress()
    progressReady = false
    local result = lib.callback.await('tss_carcollectibles:getProgress', false)
    if not result or not result.ok then return false end
    collected = result.collected or {}
    progressReady = true
    return true
end

-- Stream objects only while in StreetKings freeroam.
CreateThread(function()
    while true do
        local freeroamNow = exports.streetkings:GetGameState() == 'freeroam'
        if freeroamNow and not isFreeroam then
            isFreeroam = true
            CreateThread(function()
                while isFreeroam and not loadProgress() do Wait(2000) end
            end)
        elseif not freeroamNow and isFreeroam then
            isFreeroam = false
            progressReady = false
            clearSpawned()
        end

        if isFreeroam and progressReady then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, item in ipairs(collectibles) do
                if not collected[item.id] then
                    local range = distance(playerCoords, item.coords)
                    if range <= CarCollectiblesConfig.spawnDistance then
                        if not spawned[item.id] and not loading[item.id] then CreateThread(function() spawnCollectible(item) end) end
                    elseif range >= CarCollectiblesConfig.despawnDistance then
                        deleteSpawned(item.id)
                    end
                end
            end
        end
        Wait(CarCollectiblesConfig.streamIntervalMs)
    end
end)

-- Animate nearby objects and detect vehicle collection.
CreateThread(function()
    while true do
        if isFreeroam and next(spawned) then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
            local vehicleCoords = isDriver and GetEntityCoords(vehicle) or nil
            local now = GetGameTimer() / 1000.0

            for _, item in ipairs(collectibles) do
                local entry = spawned[item.id]
                if entry and DoesEntityExist(entry.object) then
                    entry.heading = (entry.heading + item.rotationSpeed * GetFrameTime()) % 360.0
                    local z = item.coords.z + item.floatHeight + math.sin(now * item.bobSpeed + entry.phase) * item.bobHeight
                    SetEntityCoordsNoOffset(entry.object, item.coords.x, item.coords.y, z, false, false, false)
                    SetEntityHeading(entry.object, entry.heading)

                    if isDriver and distance(vehicleCoords, item.coords) <= CarCollectiblesConfig.collectDistance then
                        CreateThread(function() collect(item) end)
                    end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then clearSpawned() end
end)

RegisterNetEvent('tss_carcollectibles:progressReset', function(setId)
    if type(setId) ~= 'string' then return end
    local prefix = setId .. ':'
    for collectibleId in pairs(collected) do
        if type(collectibleId) == 'string' and collectibleId:sub(1, #prefix) == prefix then
            collected[collectibleId] = nil
        end
    end
end)
