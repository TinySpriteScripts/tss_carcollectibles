fx_version 'cerulean'
game 'gta5'

author 'TinySprite'
description 'collectible sets for StreetKings'
version '1.0.0'

dependencies {
    'ox_lib',
    'streetkings'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

