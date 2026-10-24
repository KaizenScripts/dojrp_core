fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dojrp_core'
description 'DOJRP framework - core, hráči, joby, inventář, multicharacter'
version '1.0.0'

dependencies { 'oxmysql', 'spawnmanager' }

shared_scripts {
    'config.lua',
    'shared/items.lua',
    'shared/jobs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/inventory.lua',
    'server/multichar.lua',
}

client_scripts {
    'client/main.lua',
    'client/multichar.lua',
    'client/inventory.lua',
}

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }
