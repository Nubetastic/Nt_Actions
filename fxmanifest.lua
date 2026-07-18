game 'rdr3'
fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'A single multi action menu'
version '1.0.0'

dependencies { 'ox_lib' }


shared_scripts {
    'shared/config.lua',
    'shared/configGroups.lua',
}


client_scripts {
    'client/menu.lua',
    'client/ricx_guntwirl.lua'
}


server_scripts {
    'server/versionchecker.lua'
}