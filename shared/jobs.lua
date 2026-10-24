-- Každé povolání musí mít grade 0. salary = výplata za Config.paycheckInterval minut (do banky).
Config.jobs = {
    unemployed = {
        label = 'Nezaměstnaný',
        grades = { [0] = { label = 'Nezaměstnaný', salary = 50 } },
    },
    lspd = {
        label = 'Los Santos Police Department',
        grades = {
            [0] = { label = 'Kadet',        salary = 300 },
            [1] = { label = 'Důstojník',    salary = 400 },
            [2] = { label = 'Seržant',      salary = 500 },
            [3] = { label = 'Poručík',      salary = 600 },
            [4] = { label = 'Náčelník',     salary = 800 },
        },
    },
    lssd = {
        label = 'Los Santos Sheriff Department',
        grades = {
            [0] = { label = 'Deputy',        salary = 300 },
            [1] = { label = 'Senior Deputy', salary = 400 },
            [2] = { label = 'Sergeant',      salary = 500 },
            [3] = { label = 'Lieutenant',    salary = 600 },
            [4] = { label = 'Sheriff',       salary = 800 },
        },
    },
    doj = {
        label = 'Department of Justice',
        grades = {
            [0] = { label = 'Soudní úředník',  salary = 350 },
            [1] = { label = 'Právník',         salary = 500 },
            [2] = { label = 'Státní zástupce', salary = 650 },
            [3] = { label = 'Soudce',          salary = 800 },
            [4] = { label = 'Hlavní soudce',   salary = 1000 },
        },
    },
    ems = {
        label = 'Emergency Medical Services',
        grades = {
            [0] = { label = 'Záchranář', salary = 300 },
            [1] = { label = 'Paramedik', salary = 450 },
            [2] = { label = 'Lékař',     salary = 650 },
            [3] = { label = 'Primář',    salary = 850 },
        },
    },
}
