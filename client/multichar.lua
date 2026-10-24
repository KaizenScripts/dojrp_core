local active = false
local cam = nil
local chosen = nil      -- { slot = n, data = {...} | nil }
local spawnTarget = nil -- vec4 nebo nil (= poslední pozice)

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function newCam(pos, look, fov, interp)
    local c = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov or 50.0, false, 0)
    PointCamAtCoord(c, look.x, look.y, look.z)
    SetFocusPosAndVel(look.x, look.y, look.z, 0.0, 0.0, 0.0)
    if cam and interp then
        SetCamActiveWithInterp(c, cam, interp, 1, 1)
        local old = cam
        SetTimeout(interp + 100, function() DestroyCam(old, false) end)
    else
        if cam then DestroyCam(cam, false) end
        SetCamActive(c, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    cam = c
end

local function defaultCam(interp)
    local c = Config.camera
    newCam(c.pos, c.look, c.fov, interp)
end

local function openUI(characters)
    local spawns = {}
    for i, s in ipairs(Config.spawns) do spawns[i] = { label = s.label, desc = s.desc } end
    nui('mc_open', {
        server = Config.serverName,
        slots = Config.slots,
        characters = characters,
        spawns = spawns,
        peds = Config.peds,
        minAge = Config.minAge, maxAge = Config.maxAge,
        minHeight = Config.minHeight, maxHeight = Config.maxHeight,
    })
    SetNuiFocus(true, true)
end

local function cleanup()
    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false) cam = nil end
    ClearFocus()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
    active, chosen, spawnTarget = false, nil, nil
    DoScreenFadeIn(800)
end

-- Začátek výběru: skrytý ped na výchozím místě + dotaz na postavy
local function startSelection()
    DoScreenFadeOut(0)
    exports.spawnmanager:setAutoSpawn(false)
    local d = Config.defaultSpawn
    exports.spawnmanager:spawnPlayer({
        x = d.x, y = d.y, z = d.z, heading = d.w, model = 'mp_m_freemode_01', skipFade = true,
    }, function()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        DisplayRadar(false)
        TriggerServerEvent('dojrp:server:mc:join')
    end)
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    startSelection()
end)

RegisterNetEvent('dojrp:client:logout', function()
    DOJRP.PlayerData, DOJRP.Loaded = {}, false
    TriggerEvent('dojrp:playerLogout')
    startSelection()
end)

RegisterNetEvent('dojrp:client:mc:open', function(characters)
    if not active then
        active = true
        defaultCam()
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        DoScreenFadeIn(600)
        openUI(characters)
    else
        nui('mc_characters', { characters = characters })
    end
end)

RegisterNetEvent('dojrp:client:mc:failed', function()
    DOJRP.Notify('Postavu se nepodařilo načíst.', 'error')
    chosen, spawnTarget = nil, nil
    defaultCam()
    DoScreenFadeIn(500)
    openUI({})
    TriggerServerEvent('dojrp:server:mc:join')
end)

-- NUI callbacks ---------------------------------------------------

RegisterNUICallback('mc_select', function(data, cb)
    chosen = { slot = data.slot }
    cb(1)
end)

RegisterNUICallback('mc_create', function(data, cb)
    chosen = { slot = data.slot, data = data }
    cb(1)
end)

RegisterNUICallback('mc_delete', function(data, cb)
    TriggerServerEvent('dojrp:server:mc:delete', data.slot)
    cb(1)
end)

RegisterNUICallback('mc_preview', function(data, cb)
    cb(1)
    local s = Config.spawns[data.index]
    if not s then return defaultCam(1200) end
    local c = s.coords
    newCam(vec3(c.x - 28.0, c.y - 28.0, c.z + 32.0), vec3(c.x, c.y, c.z), 55.0, 1200)
end)

RegisterNUICallback('mc_back', function(_, cb)
    cb(1)
    defaultCam(1000)
end)

RegisterNUICallback('mc_spawn', function(data, cb)
    cb(1)
    if not chosen then return end

    local s = data.index and data.index > 0 and Config.spawns[data.index]
    spawnTarget = s and s.coords or nil

    SetNuiFocus(false, false)
    nui('mc_close')
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    TriggerServerEvent('dojrp:server:mc:play', chosen.slot, chosen.data)
end)

-- Postava načtena: model + spawn ------------------------------------

RegisterNetEvent('dojrp:client:loaded', function(data, isNew, lastPos)
    DOJRP.PlayerData = data
    DOJRP.Loaded = true

    local x, y, z, h
    if spawnTarget then
        x, y, z, h = spawnTarget.x, spawnTarget.y, spawnTarget.z, spawnTarget.w
    elseif lastPos then
        x, y, z, h = lastPos.x, lastPos.y, lastPos.z, lastPos.w or 0.0
    else
        local d = Config.defaultSpawn
        x, y, z, h = d.x, d.y, d.z, d.w
    end

    exports.spawnmanager:spawnPlayer({
        x = x, y = y, z = z, heading = h, model = data.model, skipFade = true,
    }, function()
        local ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
        RequestCollisionAtCoord(x, y, z)
        local t = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(50) end
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 20.0, false)
        if found then SetEntityCoordsNoOffset(ped, x, y, gz, false, false, false) end

        cleanup()
        TriggerEvent('dojrp:playerLoaded', data, isNew)
    end)
end)
