Config = {}

Config.serverName = 'DOJRP'
Config.adminAce = 'dojrp.admin'   -- add_ace group.admin dojrp.admin allow

-- Postavy
Config.slots = 3
Config.minAge, Config.maxAge = 16, 90
Config.minHeight, Config.maxHeight = 120, 220
Config.dateFormat = 'DD.MM.YYYY'  -- DD.MM.YYYY | MM/DD/YYYY | YYYY-MM-DD

-- Nová postava
Config.startingAccounts = { cash = 500, bank = 5000 }
Config.startJob = { name = 'unemployed', grade = 0 }
Config.startItems = {
    { name = 'phone', count = 1 },
    { name = 'water', count = 2 },
    { name = 'bread', count = 2 },
}

-- Účty (klíč = název, hodnota = popisek v UI)
Config.accounts = { cash = 'Hotovost', bank = 'Banka' }

-- Inventář (váha v gramech)
Config.inventory = { slots = 30, maxWeight = 30000, giveDistance = 3.0 }

-- Ukládání a výplaty
Config.saveInterval = 5 * 60 * 1000   -- ms
Config.paycheckInterval = 15          -- minuty

-- Výchozí spawn (skrytý ped během výběru postavy + nový hráč bez poslední pozice)
Config.defaultSpawn = vec4(195.17, -933.77, 30.69, 144.0)

-- Kamera během výběru postavy
Config.camera = {
    pos  = vec3(-75.0, -819.0, 340.0),
    look = vec3(200.0, -1000.0, 40.0),
    fov  = 50.0,
}

-- Spawn selector
Config.spawns = {
    { label = 'Legion Square',  desc = 'Centrum Los Santos',   coords = vec4(195.17, -933.77, 30.69, 144.0) },
    { label = 'Letiště LSIA',   desc = 'Mezinárodní letiště',  coords = vec4(-1037.0, -2737.0, 20.17, 330.0) },
    { label = 'Vespucci Beach', desc = 'Pláž a promenáda',     coords = vec4(-1183.0, -1525.0, 4.4, 120.0) },
    { label = 'Sandy Shores',   desc = 'Poušť Blaine County',  coords = vec4(1961.0, 3740.0, 32.34, 300.0) },
    { label = 'Paleto Bay',     desc = 'Sever mapy',           coords = vec4(-276.0, 6226.0, 31.7, 45.0) },
}

-- Modely postav místo appearance
Config.peds = {
    male = {
        { label = 'Business',  model = 'a_m_y_business_01' },
        { label = 'Casual',    model = 'a_m_y_hipster_01' },
        { label = 'Sportovec', model = 'a_m_y_runner_01' },
        { label = 'Pláž',      model = 'a_m_y_beach_01' },
        { label = 'Pracovník', model = 's_m_y_construct_01' },
    },
    female = {
        { label = 'Business',    model = 'a_f_y_business_01' },
        { label = 'Casual',      model = 'a_f_y_hipster_01' },
        { label = 'Sportovkyně', model = 'a_f_y_fitness_01' },
        { label = 'Pláž',        model = 'a_f_y_beach_01' },
        { label = 'Turistka',    model = 'a_f_y_tourist_01' },
    },
}
