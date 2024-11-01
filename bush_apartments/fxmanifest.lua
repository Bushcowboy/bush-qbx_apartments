fx_version 'cerulean'
game 'gta5'
author 'bushcowboy'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'true'