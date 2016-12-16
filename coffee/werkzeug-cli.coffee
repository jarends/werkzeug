WZ         = require './werkzeug'
pkg        = require "#{__dirname}/../package"
ArgsParser = require './args-parser'


helpText = """werkzeug (german for 'tool')

Compiles and packs your project.
Simply type 'wz' to compile and pack once.
Type 'wz -w' if you want werkzeug to watch your files,
compile and pack incremental and start the server.
"""

parser = new ArgsParser().parse process.argv,
    help: helpText
    commands: [
        name: 'watch'
        help: 'watches for changes, compiles and packs incremental and starts the server'
    ,
        name: 'help'
        help: 'print this help'
    ,
        name: 'version'
        help: 'print the version'
    ]


walk = () ->
    wz = new WZ(process.cwd())
    wz.walk()


watch = () ->
    wz = new WZ(process.cwd())
    wz.watch()


if parser.error
    console.log 'werkzeug ERROR: ', error
    parser.printHelp()
else
    if parser.cmds.length == 0
        walk()
    else
        cmd = parser.cmds[0]
        switch cmd.name
            when 'watch'   then watch()
            when 'help'    then parser.printHelp()
            when 'version' then console.log 'v' + pkg.version

