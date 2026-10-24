local open = false

local function defs()
    local out = {}
    for name, it in pairs(Config.items) do
        out[name] = { label = it.label, weight = it.weight, icon = it.icon, description = it.description, stack = it.stack ~= false }
    end
    return out
end

local function invList()
    local out = {}
    for slot, s in pairs(DOJRP.PlayerData.inventory or {}) do
        out[#out + 1] = { slot = slot, name = s.name, count = s.count }
    end
    return out
end

local function payload()
    return {
        inventory = invList(),
        accounts = DOJRP.PlayerData.accounts or {},
    }
end

local function openInventory()
    if open or not DOJRP.Loaded or IsPauseMenuActive() then return end
    open = true
    local p = payload()
    SendNUIMessage({
        action = 'inv_open',
        server = Config.serverName,
        items = defs(),
        slots = Config.inventory.slots,
        maxWeight = Config.inventory.maxWeight,
        inventory = p.inventory,
        accounts = p.accounts,
        accountLabels = Config.accounts,
    })
    SetNuiFocus(true, true)
end

local function closeInventory()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'inv_close' })
end

function DOJRP.OnInventoryUpdate()
    if open then
        local p = payload()
        SendNUIMessage({ action = 'inv_update', inventory = p.inventory, accounts = p.accounts })
    end
end

RegisterCommand('dojrp_inventory', function()
    if open then closeInventory() else openInventory() end
end, false)
RegisterKeyMapping('dojrp_inventory', 'Otevřít inventář', 'keyboard', 'F2')

AddEventHandler('dojrp:playerLogout', closeInventory)

RegisterNUICallback('inv_close', function(_, cb)
    cb(1)
    closeInventory()
end)

RegisterNUICallback('inv_use', function(data, cb)
    cb(1)
    TriggerServerEvent('dojrp:server:inv:use', data.slot)
end)

RegisterNUICallback('inv_move', function(data, cb)
    cb(1)
    TriggerServerEvent('dojrp:server:inv:move', data.from, data.to)
end)

RegisterNUICallback('inv_drop', function(data, cb)
    cb(1)
    TriggerServerEvent('dojrp:server:inv:drop', data.slot, data.count)
end)

local function closestPlayer()
    local me = GetEntityCoords(PlayerPedId())
    local best, dist = nil, Config.inventory.giveDistance
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= PlayerId() then
            local d = #(me - GetEntityCoords(GetPlayerPed(pl)))
            if d < dist then dist, best = d, GetPlayerServerId(pl) end
        end
    end
    return best
end

RegisterNUICallback('inv_give', function(data, cb)
    cb(1)
    local target = closestPlayer()
    if not target then return DOJRP.Notify('Nikdo není poblíž.', 'error') end
    TriggerServerEvent('dojrp:server:inv:give', data.slot, data.count, target)
end)
