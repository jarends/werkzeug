FSE        = require 'fs-extra'
Path       = require 'path'
WZ         = require './werkzeug'
pkg        = require "#{__dirname}/../package.json"
ArgsParser = require './args-parser'
FSU        = require './utils/fsu'
base       = process.cwd()
cfg        = FSU.require base,  '.werkzeug'


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
        name: 'init'
        help: 'copy the default config file to your project'
    ,
        name: 'version'
        help: 'print the version'
    ,
        name: 'help'
        help: 'print this help'
    ]


nothingToDo = () ->
    console.log '\r\nNo config found. Nothing to do ;-)\r\n'
    process.exit 0


init = () ->
    inPath  = Path.join  __dirname, '..', '.default.werkzeug'
    outPath = Path.join base, '.werkzeug'
    FSE.copySync inPath, outPath
    console.log '\r\n.werkzeug file created successfully\r\n'


walk = () ->
    if not cfg
        nothingToDo()
    else
        wz = new WZ(base, cfg)
        wz.walk()


watch = () ->
    if not cfg
        nothingToDo()
    else
        wz = new WZ(base, cfg)
        wz.watch()


if parser.error
    console.log '\r\nERROR: ', parser.error
    parser.printCommands()
else
    if parser.cmds.length == 0
        walk()
    else
        cmd = parser.cmds[0]
        switch cmd.name
            when 'watch'   then watch()
            when 'init'    then init()
            when 'help'    then parser.printHelp()
            when 'version' then console.log 'v' + pkg.version

