local Players = DOJRP.Players

function DOJRP.AttachInventory(self)
    local src = self.source
    local cfg = Config.inventory

    local function sync() TriggerClientEvent('dojrp:client:update', src, 'inventory', self.inventory) end

    local function stackable(name, meta)
        local it = Config.items[name]
        return it and it.stack ~= false and not meta
    end

    local function weight()
        local w = 0
        for _, s in pairs(self.inventory) do
            local it = Config.items[s.name]
            if it then w = w + it.weight * s.count end
        end
        return w
    end

    local function findStack(name)
        for i = 1, cfg.slots do
            local s = self.inventory[i]
            if s and s.name == name and not s.metadata then return i end
        end
    end

    local function freeSlots()
        local n = 0
        for i = 1, cfg.slots do if not self.inventory[i] then n = n + 1 end end
        return n
    end

    local function firstFree()
        for i = 1, cfg.slots do if not self.inventory[i] then return i end end
    end

    self.getWeight = weight
    self.getInventory = function() return self.inventory end

    self.canCarry = function(name, count, meta)
        local it = Config.items[name]
        count = math.floor(tonumber(count) or 0)
        if not it or count < 1 then return false end
        if weight() + it.weight * count > cfg.maxWeight then return false end
        local need
        if stackable(name, meta) then need = findStack(name) and 0 or 1 else need = count end
        return freeSlots() >= need
    end

    self.addItem = function(name, count, meta)
        count = math.floor(tonumber(count) or 1)
        if not self.canCarry(name, count, meta) then return false end
        if stackable(name, meta) then
            local i = findStack(name)
            if i then
                self.inventory[i].count = self.inventory[i].count + count
            else
                self.inventory[firstFree()] = { name = name, count = count }
            end
        else
            local it = Config.items[name]
            for _ = 1, count do
                self.inventory[firstFree()] = { name = name, count = 1, metadata = meta }
            end
        end
        sync()
        return true
    end

    self.getItemCount = function(name)
        local c = 0
        for _, s in pairs(self.inventory) do
            if s.name == name then c = c + s.count end
        end
        return c
    end

    self.hasItem = function(name, count)
        return self.getItemCount(name) >= (count or 1)
    end

    self.removeItem = function(name, count)
        count = math.floor(tonumber(count) or 1)
        if count < 1 or self.getItemCount(name) < count then return false end
        for i = 1, cfg.slots do
            local s = self.inventory[i]
            if s and s.name == name then
                local take = math.min(s.count, count)
                s.count = s.count - take
                count = count - take
                if s.count <= 0 then self.inventory[i] = nil end
                if count <= 0 then break end
            end
        end
        sync()
        return true
    end
end

-- Použitelné předměty ----------------------------------------------------

local function usable(name, fn) DOJRP.UsableItems[name] = fn end

usable('water', function(src, _, p)
    if p.removeItem('water', 1) then p.notify('Napil ses vody.', 'success') end
end)
usable('bread', function(src, _, p)
    if p.removeItem('bread', 1) then p.notify('Snědl jsi chléb.', 'success') end
end)
usable('bandage', function(src, _, p)
    if p.removeItem('bandage', 1) then
        TriggerClientEvent('dojrp:client:heal', src, 25)
        p.notify('Použil jsi obvaz.', 'success')
    end
end)

-- Události z UI ----------------------------------------------------------

local function validSlot(n)
    n = tonumber(n)
    if n and n >= 1 and n <= Config.inventory.slots and n == math.floor(n) then return n end
end

RegisterNetEvent('dojrp:server:inv:use', function(slot)
    local src = source
    local p = Players[src]
    slot = validSlot(slot)
    if not p or not slot then return end
    local s = p.inventory[slot]
    if not s then return end
    local fn = DOJRP.UsableItems[s.name]
    if not fn then return p.notify('Tento předmět nejde použít.', 'error') end
    fn(src, s, p)
end)

RegisterNetEvent('dojrp:server:inv:move', function(from, to)
    local src = source
    local p = Players[src]
    from, to = validSlot(from), validSlot(to)
    if not p or not from or not to or from == to then return end
    local a, b = p.inventory[from], p.inventory[to]
    if not a then return end

    local itA = Config.items[a.name]
    if b and a.name == b.name and itA.stack ~= false and not a.metadata and not b.metadata then
        b.count = b.count + a.count
        p.inventory[from] = nil
    else
        p.inventory[from], p.inventory[to] = b, a
    end
    TriggerClientEvent('dojrp:client:update', src, 'inventory', p.inventory)
end)

RegisterNetEvent('dojrp:server:inv:drop', function(slot, count)
    local src = source
    local p = Players[src]
    slot = validSlot(slot)
    count = math.floor(tonumber(count) or 0)
    if not p or not slot or count < 1 then return end
    local s = p.inventory[slot]
    if not s then return end
    count = math.min(count, s.count)
    s.count = s.count - count
    if s.count <= 0 then p.inventory[slot] = nil end
    TriggerClientEvent('dojrp:client:update', src, 'inventory', p.inventory)
    p.notify(('Zahodil jsi %dx %s.'):format(count, Config.items[s.name].label), 'info')
    TriggerEvent('dojrp:server:itemDropped', src, s.name, count)
end)

RegisterNetEvent('dojrp:server:inv:give', function(slot, count, target)
    local src = source
    local p, t = Players[src], Players[tonumber(target)]
    slot = validSlot(slot)
    count = math.floor(tonumber(count) or 0)
    if not p or not t or not slot or count < 1 or t.source == src then return end

    local s = p.inventory[slot]
    if not s then return end
    count = math.min(count, s.count)

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(t.source)))
    if d > Config.inventory.giveDistance + 1.0 then
        return p.notify('Hráč je příliš daleko.', 'error')
    end
    if not t.canCarry(s.name, count, s.metadata) then
        return p.notify('Druhý hráč to neunese.', 'error')
    end

    local name, meta = s.name, s.metadata
    local label = Config.items[name].label
    s.count = s.count - count
    if s.count <= 0 then p.inventory[slot] = nil end
    TriggerClientEvent('dojrp:client:update', src, 'inventory', p.inventory)
    t.addItem(name, count, meta)

    p.notify(('Předal jsi %dx %s.'):format(count, label), 'success')
    t.notify(('Dostal jsi %dx %s.'):format(count, label), 'success')
end)
