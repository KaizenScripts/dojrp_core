DOJRP = { Players = {}, UsableItems = {}, Callbacks = {} }
local Players = DOJRP.Players

local function decode(str, default)
    if not str or str == '' then return default end
    local ok, res = pcall(json.decode, str)
    if ok and type(res) == 'table' then return res end
    return default
end
DOJRP.Decode = decode

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `dojrp_characters` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `license` VARCHAR(60) NOT NULL,
            `slot` TINYINT UNSIGNED NOT NULL,
            `firstname` VARCHAR(32) NOT NULL,
            `lastname` VARCHAR(32) NOT NULL,
            `dob` VARCHAR(12) NOT NULL,
            `sex` CHAR(1) NOT NULL,
            `height` SMALLINT UNSIGNED NOT NULL DEFAULT 175,
            `model` VARCHAR(64) NOT NULL,
            `accounts` LONGTEXT NULL,
            `job` VARCHAR(32) NOT NULL DEFAULT 'unemployed',
            `job_grade` INT NOT NULL DEFAULT 0,
            `on_duty` TINYINT(1) NOT NULL DEFAULT 0,
            `position` LONGTEXT NULL,
            `inventory` LONGTEXT NULL,
            `metadata` LONGTEXT NULL,
            `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `last_played` TIMESTAMP NULL,
            UNIQUE KEY `license_slot` (`license`, `slot`)
        )
    ]])
end)

function DOJRP.GetLicense(src)
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if v:sub(1, 8) == 'license:' then return v:sub(9) end
    end
end

function DOJRP.Notify(src, msg, type, duration)
    TriggerClientEvent('dojrp:client:notify', src, msg, type or 'info', duration or 5000)
end

local function resolveJob(name, grade)
    local j = Config.jobs[name]
    if not j then name, j, grade = 'unemployed', Config.jobs.unemployed, 0 end
    grade = tonumber(grade) or 0
    local g = j.grades[grade]
    if not g then grade = 0 g = j.grades[0] end
    return { name = name, label = j.label, grade = grade, gradeLabel = g.label, salary = g.salary or 0 }
end
DOJRP.ResolveJob = resolveJob

-- Hráč ----------------------------------------------------------------

function DOJRP.CreatePlayer(src, row)
    local self = {
        source = src, charId = row.id, license = row.license, slot = row.slot,
        firstname = row.firstname, lastname = row.lastname, dob = row.dob,
        sex = row.sex, height = row.height, model = row.model,
        metadata = decode(row.metadata, {}),
        onDuty = row.on_duty == 1 or row.on_duty == true,
        job = resolveJob(row.job, row.job_grade),
        accounts = decode(row.accounts, {}),
        inventory = {},
        spawned = false,
    }

    local pos = decode(row.position, nil)
    self.position = (pos and pos.x) and pos or nil

    for k in pairs(Config.accounts) do self.accounts[k] = tonumber(self.accounts[k]) or 0 end
    for k, v in pairs(decode(row.inventory, {})) do
        local i = tonumber(k)
        if i and type(v) == 'table' and Config.items[v.name] then self.inventory[i] = v end
    end

    local function sync(key, value) TriggerClientEvent('dojrp:client:update', src, key, value) end
    local function pubJob()
        local j = self.job
        return { name = j.name, label = j.label, grade = j.grade, gradeLabel = j.gradeLabel, salary = j.salary, onDuty = self.onDuty }
    end

    self.getPublic = function()
        return {
            charId = self.charId, firstname = self.firstname, lastname = self.lastname, dob = self.dob,
            sex = self.sex, height = self.height, model = self.model,
            accounts = self.accounts, job = pubJob(), inventory = self.inventory, metadata = self.metadata,
        }
    end

    self.getName = function() return self.firstname .. ' ' .. self.lastname end
    self.notify = function(msg, type, duration) DOJRP.Notify(src, msg, type, duration) end

    -- peníze
    self.getMoney = function(acc) return self.accounts[acc] or 0 end
    self.setMoney = function(acc, amt)
        amt = math.floor(tonumber(amt) or -1)
        if self.accounts[acc] == nil or amt < 0 then return false end
        self.accounts[acc] = amt
        sync('accounts', self.accounts)
        return true
    end
    self.addMoney = function(acc, amt)
        amt = math.floor(tonumber(amt) or 0)
        if self.accounts[acc] == nil or amt <= 0 then return false end
        return self.setMoney(acc, self.accounts[acc] + amt)
    end
    self.removeMoney = function(acc, amt)
        amt = math.floor(tonumber(amt) or 0)
        if self.accounts[acc] == nil or amt <= 0 or self.accounts[acc] < amt then return false end
        return self.setMoney(acc, self.accounts[acc] - amt)
    end

    -- job
    self.getJob = pubJob
    self.setJob = function(name, grade)
        local j = Config.jobs[name]
        grade = tonumber(grade) or 0
        if not j or not j.grades[grade] then return false end
        self.job = resolveJob(name, grade)
        self.onDuty = name ~= 'unemployed'
        sync('job', pubJob())
        TriggerEvent('dojrp:server:jobUpdated', src, pubJob())
        return true
    end
    self.setDuty = function(state)
        if self.job.name == 'unemployed' then return false end
        self.onDuty = state and true or false
        sync('job', pubJob())
        TriggerEvent('dojrp:server:jobUpdated', src, pubJob())
        return true
    end

    -- metadata
    self.getMeta = function(key) return self.metadata[key] end
    self.setMeta = function(key, value)
        self.metadata[key] = value
        sync('metadata', self.metadata)
    end

    -- ukládání
    self.save = function()
        local ped = GetPlayerPed(src)
        if self.spawned and ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            self.position = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
        end
        local inv = {}
        for i, v in pairs(self.inventory) do inv[tostring(i)] = v end
        MySQL.update.await(
            'UPDATE dojrp_characters SET accounts=?, job=?, job_grade=?, on_duty=?, position=?, inventory=?, metadata=? WHERE id=?',
            { json.encode(self.accounts), self.job.name, self.job.grade, self.onDuty and 1 or 0,
              json.encode(self.position or {}), json.encode(inv), json.encode(self.metadata), self.charId })
    end

    DOJRP.AttachInventory(self)
    return self
end

-- Callbacky -------------------------------------------------------------

function DOJRP.RegisterCallback(name, fn) DOJRP.Callbacks[name] = fn end

RegisterNetEvent('dojrp:server:cb', function(name, id, ...)
    local src = source
    local fn = DOJRP.Callbacks[name]
    if not fn then return TriggerClientEvent('dojrp:client:cb', src, id) end
    local args = { ... }
    local res = table.pack(pcall(fn, src, table.unpack(args)))
    if not res[1] then
        print(('[dojrp_core] callback "%s" selhal: %s'):format(name, tostring(res[2])))
        return TriggerClientEvent('dojrp:client:cb', src, id)
    end
    TriggerClientEvent('dojrp:client:cb', src, id, table.unpack(res, 2, res.n))
end)

-- Exporty --------------------------------------------------------------

exports('GetPlayer', function(src) return Players[src] end)
exports('GetPlayers', function() return Players end)
exports('GetPlayerByCharId', function(charId)
    for _, p in pairs(Players) do if p.charId == charId then return p end end
end)
exports('RegisterUsableItem', function(name, fn) DOJRP.UsableItems[name] = fn end)
exports('RegisterCallback', function(name, fn) DOJRP.RegisterCallback(name, fn) end)
exports('Notify', function(src, msg, type, duration) DOJRP.Notify(src, msg, type, duration) end)
exports('GetItems', function() return Config.items end)
exports('GetJobs', function() return Config.jobs end)

local function wrap(method)
    return function(src, ...)
        local p = Players[src]
        if p and p[method] then return p[method](...) end
        return false
    end
end
for _, m in ipairs({ 'getMoney', 'addMoney', 'removeMoney', 'setMoney', 'setJob', 'getJob', 'setDuty',
                     'addItem', 'removeItem', 'getItemCount', 'hasItem', 'canCarry' }) do
    local name = m:sub(1, 1):upper() .. m:sub(2)
    exports(name, wrap(m))
end

-- Příkazy --------------------------------------------------------------

local function isAdmin(src) return src == 0 or IsPlayerAceAllowed(src, Config.adminAce) end
local function reply(src, msg, type)
    if src == 0 then print('[dojrp_core] ' .. msg) else DOJRP.Notify(src, msg, type or 'info') end
end
local function adminCmd(name, fn)
    RegisterCommand(name, function(src, args)
        if not isAdmin(src) then return end
        fn(src, args)
    end, false)
end

adminCmd('setjob', function(src, a)
    local p = Players[tonumber(a[1])]
    if not p then return reply(src, 'Hráč nenalezen.', 'error') end
    if p.setJob(a[2], a[3] or 0) then reply(src, ('Job nastaven: %s (%s)'):format(a[2], a[3] or 0), 'success')
    else reply(src, 'Neplatný job / grade.', 'error') end
end)

adminCmd('givemoney', function(src, a)
    local p = Players[tonumber(a[1])]
    if not p then return reply(src, 'Hráč nenalezen.', 'error') end
    if p.addMoney(a[2], a[3]) then reply(src, 'Peníze přidány.', 'success')
    else reply(src, 'Použití: /givemoney [id] [cash|bank] [částka]', 'error') end
end)

adminCmd('setmoney', function(src, a)
    local p = Players[tonumber(a[1])]
    if not p then return reply(src, 'Hráč nenalezen.', 'error') end
    if p.setMoney(a[2], a[3]) then reply(src, 'Peníze nastaveny.', 'success')
    else reply(src, 'Použití: /setmoney [id] [cash|bank] [částka]', 'error') end
end)

adminCmd('giveitem', function(src, a)
    local p = Players[tonumber(a[1])]
    if not p then return reply(src, 'Hráč nenalezen.', 'error') end
    if p.addItem(a[2], tonumber(a[3]) or 1) then reply(src, 'Předmět přidán.', 'success')
    else reply(src, 'Nelze přidat (neznámý předmět / plný inventář).', 'error') end
end)

RegisterCommand('duty', function(src)
    local p = Players[src]
    if not p then return end
    if p.setDuty(not p.onDuty) then
        p.notify(p.onDuty and 'Nastoupil jsi do služby.' or 'Skončil jsi službu.', 'info')
    else
        p.notify('Nemáš žádné zaměstnání.', 'error')
    end
end, false)

-- Ukládání, výplaty ------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.saveInterval)
        for _, p in pairs(Players) do p.save() end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.paycheckInterval * 60000)
        for _, p in pairs(Players) do
            local sal = p.job.salary
            if sal > 0 and (p.job.name == 'unemployed' or p.onDuty) then
                p.addMoney('bank', sal)
                p.notify(('Výplata: $%d'):format(sal), 'success')
            end
        end
    end
end)

AddEventHandler('playerDropping', function()
    local p = Players[source]
    if p then
        p.save()
        TriggerEvent('dojrp:server:playerLogout', source, p)
    end
end)

AddEventHandler('playerDropped', function()
    Players[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(Players) do p.save() end
end)
