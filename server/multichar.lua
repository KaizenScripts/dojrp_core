local Players = DOJRP.Players
local busy = {}

local function listCharacters(src)
    local lic = DOJRP.GetLicense(src)
    if not lic then return {} end
    return MySQL.query.await(
        'SELECT slot, firstname, lastname, dob, sex, job, job_grade FROM dojrp_characters WHERE license = ? ORDER BY slot',
        { lic }) or {}
end

local function sendList(src)
    TriggerClientEvent('dojrp:client:mc:open', src, listCharacters(src))
end

local function validName(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s < 2 or #s > 24 then return nil end
    if not s:match("^[%a\128-\255%-' ]+$") then return nil end
    return s
end

local function formatDate(y, m, d)
    local f = Config.dateFormat
    if f == 'MM/DD/YYYY' then return ('%02d/%02d/%04d'):format(m, d, y) end
    if f == 'YYYY-MM-DD' then return ('%04d-%02d-%02d'):format(y, m, d) end
    return ('%02d.%02d.%04d'):format(d, m, y)
end

local function pedAllowed(sex, model)
    for _, p in ipairs(Config.peds[sex == 'f' and 'female' or 'male']) do
        if p.model == model then return true end
    end
    return false
end

local function fail(src)
    busy[src] = nil
    TriggerClientEvent('dojrp:client:mc:failed', src)
end

RegisterNetEvent('dojrp:server:mc:join', function()
    local src = source
    if Players[src] then return end
    sendList(src)
end)

RegisterNetEvent('dojrp:server:mc:delete', function(slot)
    local src = source
    slot = tonumber(slot)
    if Players[src] or busy[src] or not slot or slot < 1 or slot > Config.slots then return end
    local lic = DOJRP.GetLicense(src)
    if not lic then return end
    MySQL.query.await('DELETE FROM dojrp_characters WHERE license = ? AND slot = ?', { lic, slot })
    TriggerEvent('dojrp:server:characterDeleted', src, lic, slot)
    sendList(src)
end)

RegisterNetEvent('dojrp:server:mc:play', function(slot, data)
    local src = source
    slot = tonumber(slot)
    if Players[src] or busy[src] or not slot or slot < 1 or slot > Config.slots then return end
    local lic = DOJRP.GetLicense(src)
    if not lic then return fail(src) end
    busy[src] = true

    local row = MySQL.single.await('SELECT * FROM dojrp_characters WHERE license = ? AND slot = ?', { lic, slot })
    local isNew = false

    if not row then
        if type(data) ~= 'table' then return fail(src) end
        local first, last = validName(data.firstname), validName(data.lastname)
        local sex = data.sex == 'f' and 'f' or (data.sex == 'm' and 'm' or nil)
        local height = tonumber(data.height)
        local y, m, d = tostring(data.date or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
        if not first or not last or not sex or not height or not y then return fail(src) end

        y, m, d = tonumber(y), tonumber(m), tonumber(d)
        local now = os.date('*t')
        local age = now.year - y - ((now.month < m or (now.month == m and now.day < d)) and 1 or 0)
        if m < 1 or m > 12 or d < 1 or d > 31 or age < Config.minAge or age > Config.maxAge then return fail(src) end
        if height < Config.minHeight or height > Config.maxHeight then return fail(src) end
        if not pedAllowed(sex, data.model) then return fail(src) end

        local id = MySQL.insert.await(
            'INSERT INTO dojrp_characters (license, slot, firstname, lastname, dob, sex, height, model, accounts, job, job_grade, inventory, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { lic, slot, first, last, formatDate(y, m, d), sex, math.floor(height), data.model,
              json.encode(Config.startingAccounts), Config.startJob.name, Config.startJob.grade, '{}', '{}' })
        if not id then return fail(src) end

        row = MySQL.single.await('SELECT * FROM dojrp_characters WHERE id = ?', { id })
        isNew = true
    end

    if not row then return fail(src) end

    local p = DOJRP.CreatePlayer(src, row)
    if isNew then
        for _, it in ipairs(Config.startItems) do p.addItem(it.name, it.count) end
        p.save()
    end

    Players[src] = p
    p.spawned = true
    busy[src] = nil
    MySQL.update('UPDATE dojrp_characters SET last_played = NOW() WHERE id = ?', { p.charId })

    TriggerClientEvent('dojrp:client:loaded', src, p.getPublic(), isNew, p.position)
    TriggerEvent('dojrp:server:playerLoaded', src, p, isNew)
end)

local function logout(src)
    local p = Players[src]
    if not p then return end
    p.save()
    TriggerEvent('dojrp:server:playerLogout', src, p)
    Players[src] = nil
    TriggerClientEvent('dojrp:client:logout', src)
end

RegisterNetEvent('dojrp:server:logout', function() logout(source) end)
exports('Logout', logout)

AddEventHandler('playerDropped', function() busy[source] = nil end)
