Path   = require 'path'
CP     = require 'child_process'
IPC    = require './utils/ipc'
SW     = require './utils/stopwatch'
PH     = require './utils/path-helper'
Log    = require './utils/log'
TS     = Path.join __dirname, 'compiler', 'ts'
COFFEE = Path.join __dirname, 'compiler', 'coffee'
SASS   = Path.join __dirname, 'compiler', 'sass'
LESS   = Path.join __dirname, 'compiler', 'less'
STYL   = Path.join __dirname, 'compiler', 'stylus'
ASSET  = Path.join __dirname, 'compiler', 'assets'

#TODO: use a generalized compiler construct

class Compiler


    constructor: (@wz) ->
        @cfg         = @wz.cfg
        @initialized = false
        @ts          = ipc: new IPC(CP.fork(TS),    @), compiled: false
        @coffee      = ipc: new IPC(CP.fork(COFFEE),@), compiled: false
        @sass        = ipc: new IPC(CP.fork(SASS),  @), compiled: false
        @less        = ipc: new IPC(CP.fork(LESS),  @), compiled: false
        @styl        = ipc: new IPC(CP.fork(STYL),  @), compiled: false
        @assets      = ipc: new IPC(CP.fork(ASSET), @), compiled: false
        @errors      = []
        @warnings    = []

        @ts.ipc.send     'init', @cfg
        @coffee.ipc.send 'init', @cfg
        @sass.ipc.send   'init', @cfg
        @less.ipc.send   'init', @cfg
        @styl.ipc.send   'init', @cfg
        @assets.ipc.send 'init', @cfg


    compile: () ->
        ts        = []
        coffee    = []
        sass      = []
        less      = []
        styl      = []
        assets    = []

        tsRoot     = PH.getIn @cfg, 'ts'
        coffeeRoot = PH.getIn @cfg, 'coffee'
        sassRoot   = PH.getIn @cfg, 'sass'
        lessRoot   = PH.getIn @cfg, 'less'
        stylRoot   = PH.getIn @cfg, 'styl'
        assetsRoot = PH.getIn @cfg, 'assets'

        @ts.compiled     = false
        @coffee.compiled = false
        @sass.compiled   = false
        @less.compiled   = false
        @styl.compiled   = false
        @assets.compiled = false

        SW.start 'compiler.all'
        SW.start 'compiler.ts'
        SW.start 'compiler.coffee'
        SW.start 'compiler.sass'
        SW.start 'compiler.less'
        SW.start 'compiler.styl'
        SW.start 'compiler.assets'

        @errors   = []
        @warnings = []
        @files    = []

        for file in @wz.files

            if file.dirty or file.errors
                path    = file.path
                removed = file.removed
                used    = false

                f = path:path, removed:removed, error:false

                # add removed files also to update ts file map
                # allow d.ts files from everywhere
                if PH.testTS(path) and (path.indexOf(tsRoot) == 0 or /\.d\.ts/.test path)
                    ts.push f
                    used = true

                else if PH.testCoffee(path) and not removed and path.indexOf(coffeeRoot) == 0
                    coffee.push f
                    used = true

                else if PH.testSass(path) and not removed and path.indexOf(sassRoot) == 0
                    sass.push f
                    used = true

                else if PH.testLess(path) and not removed and path.indexOf(lessRoot) == 0
                    less.push f
                    used = true

                else if PH.testStyl(path) and not removed and path.indexOf(stylRoot) == 0
                    styl.push f
                    used = true

                # ignore removed files in this else -> all removed files will be added separate
                else if path.indexOf(assetsRoot) == 0 and not removed
                    assets.push f
                    used = true

                # add all removed to assets
                if removed
                    assets.push f
                    used = true

                if used
                    @files.push f

        if assets.length
            @assets.ipc.send 'compile', assets
        else
            @assets.compiled = true

        if sass.length
            @sass.ipc.send 'compile', sass
        else
            @sass.compiled = true

        if less.length
            @less.ipc.send 'compile', less
        else
            @less.compiled = true

        if styl.length
            @styl.ipc.send 'compile', styl
        else
            @styl.compiled = true

        if ts.length
            @ts.ipc.send 'compile', ts
        else
            @ts.compiled = true

        if coffee.length
            @coffee.ipc.send 'compile', coffee
        else
            @coffee.compiled = true

        l = @files.length

        if l == 0
            return false

        console.log() if @initialized
        Log.info 'compiler', 'starting'.white + " ... (#{l} #{Log.count l, 'file'})"
        true




    compiled: (comp, errors, warnings) ->
        @[comp].compiled = true

        errors = errors or []
        for error in errors
            @errors.push error
            path        = error.path
            file        = @wz.fileMap[path]
            if file
                file.errors = true
            #TODO: handle error somehow
            else
                #console.log 'error in file, but file not in root: ', path

        warnings = warnings or []
        for warning in warnings
            @warnings.push warning

        t  = SW.stop 'compiler.' + comp
        le = errors.length
        lw = warnings.length
        Log.info comp, 'compiled', t, le, lw

        if @ts.compiled and @coffee.compiled and @sass.compiled and @less.compiled and @styl.compiled and @assets.compiled
            @initialized = true
            t = SW.stop 'compiler.all'
            l = @errors.length
            Log.info 'compiler', 'ready', t, l
            @wz.compiled()

        null




    exit: () ->
        @ts.ipc.exit()
        @coffee.ipc.exit()
        @sass.ipc.exit()
        @less.ipc.exit()
        @styl.ipc.exit()
        @assets.ipc.exit()
        null


module.exports = Compiler
