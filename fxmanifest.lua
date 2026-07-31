game 'rdr3'
fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'Shared object pose libraries with administrative batch review'
version '2.1.0'

dependencies { 'ox_lib', 'ox_target' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}


shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/configScenarios.lua',
    'shared/configGroups.lua',
    'shared/configTarget.lua',
}


client_scripts {
    'client/ui.lua',
    'client/target.lua',
    'client/review.lua',
    'client/menu.lua'
}


server_scripts {
    'server/versionchecker.lua',
    'server/target.lua',
    'server/review.lua'
}
