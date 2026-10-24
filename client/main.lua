DOJRP = { PlayerData = {}, Loaded = false }

local cbId, pendingCb = 0, {}

function DOJRP.TriggerCallback(name, cb, ...)
    cbId = cbId + 1
    pendingCb[cbId] = cb
    TriggerServerEvent('dojrp:server:cb', name, cbId, ...)
end

RegisterNetEvent('dojrp:client:cb', function(id, ...)
    local cb = pendingCb[id]
    pendingCb[id] = nil
    if cb then cb(...) end
end)

function DOJRP.Notify(msg, type, duration)
    SendNUIMessage({ action = 'notify', message = msg, type = type or 'info', duration = duration or 5000 })
end
RegisterNetEvent('dojrp:client:notify', DOJRP.Notify)

function DOJRP.HasItem(name, count)
    local total = 0
    for _, s in pairs(DOJRP.PlayerData.inventory or {}) do
        if s.name == name then total = total + s.count end
    end
    return total >= (count or 1)
end

RegisterNetEvent('dojrp:client:update', function(key, value)
    DOJRP.PlayerData[key] = value
    TriggerEvent('dojrp:dataUpdated', key, value)
    if key == 'job' then TriggerEvent('dojrp:jobUpdated', value) end
    if key == 'inventory' and DOJRP.OnInventoryUpdate then DOJRP.OnInventoryUpdate() end
    if key == 'accounts' and DOJRP.OnInventoryUpdate then DOJRP.OnInventoryUpdate() end
end)

RegisterNetEvent('dojrp:client:heal', function(amount)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
end)

RegisterCommand('logout', function()
    if DOJRP.Loaded then TriggerServerEvent('dojrp:server:logout') end
end, false)

exports('GetPlayerData', function() return DOJRP.PlayerData end)
exports('IsLoaded', function() return DOJRP.Loaded end)
exports('Notify', DOJRP.Notify)
exports('HasItem', DOJRP.HasItem)
exports('TriggerCallback', function(name, cb, ...) DOJRP.TriggerCallback(name, cb, ...) end)
