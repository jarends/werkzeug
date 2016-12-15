Path    = require 'path'
CP      = require 'child_process'
IPC     = require './utils/ipc'
SW      = require './utils/stopwatch'
PH      = require './utils/path-helper'
Log     = require './utils/log'
CLIENTS = [
    'assets',
    'styl',
    'less',
    'sass',
    'coffee',
    'ts'
]


class CompilerClient


    constructor: (@type, @compiler) ->
        path      = Path.join __dirname, 'compiler', @type
        @cfg      = @compiler.cfg
        @ipc      = new IPC(CP.fork(path), @compiler)
        @root     = PH.getIn @cfg, @type
        @compiled = false
        @files    = null
        @ipc.send 'init', @cfg


    prepare: () ->
        @files    = []
        @errors   = []
        @warnings = []
        @compiled = false
        SW.start 'compiler.' + @type
        null


    add: (file) ->
        @files.push file
        null


    compile: () ->
        if @files.length
            @ipc.send 'compile', @files
        else
            @compiled = true
        null


    exit: () ->
        @ipc.exit()
        null




class Compiler


    constructor: (@wz) ->
        @cfg         = @wz.cfg
        @initialized = false
        @clients     = []
        @errors      = []
        @warnings    = []

        for type in CLIENTS
            if @isEnabled(type)
                client  = new CompilerClient(type, @)
                @[type] = client
                @clients.push client
        null


    isEnabled: (type) ->
        @cfg[type].enabled


    compile: () ->
        SW.start 'compiler.all'
        @errors   = []
        @warnings = []
        @files    = []

        client.prepare() for client in @clients

        for file in @wz.files

            if file.dirty or file.errors
                path    = file.path
                removed = file.removed
                used    = false

                f = path:path, removed:removed, error:false

                # add removed files also to update ts file map
                # allow d.ts files from everywhere #TODO: maybe change this
                if @isEnabled('ts') and PH.testTS(path) and (path.indexOf(@ts.root) == 0 or /\.d\.ts/.test path)
                    @ts.add f
                    used = true

                else if @isEnabled('coffee') and PH.testCoffee(path) and not removed and path.indexOf(@coffee.root) == 0
                    @coffee.add f
                    used = true

                else if @isEnabled('sass') and PH.testSass(path) and not removed and path.indexOf(@sass.root) == 0
                    @sass.add f
                    used = true

                else if @isEnabled('less') and PH.testLess(path) and not removed and path.indexOf(@less.root) == 0
                    @less.add f
                    used = true

                else if @isEnabled('styl') and PH.testStyl(path) and not removed and path.indexOf(@styl.root) == 0
                    @styl.add f
                    used = true

                # ignore removed files in this else -> all removed files will be added separate
                else if @isEnabled('assets') and path.indexOf(@assets.root) == 0 and not removed
                    @assets.add f
                    used = true

                # add all removed to assets
                if removed
                    @assets.add f
                    used = true

                if used
                    @files.push f

        client.compile() for client in @clients

        l = @files.length
        if l
            console.log() if @initialized
            #Log.info 'compiler', "starting ... (#{l} #{Log.count l, 'file'})" + JSON.stringify @files
            Log.info 'compiler', "starting ... (#{l} #{Log.count l, 'file'})"
            return true

        false




    compiled: (type, errors) ->
        try
            client          = @[type]
            client.compiled = true
            errors          = errors or []
            for error in errors
                if error.error
                    @errors.push error
                    client.errors.push error
                else if error.warning
                    @warnings.push error
                    client.warnings.push error

                error.type  = type if not error.type
                path        = error.path
                file        = @wz.fileMap[path]
                if file and error.error
                    file.errors = true
                #TODO: handle error somehow
                else
                    #console.log 'error in file, but file not in root: ', path

            t  = SW.stop 'compiler.' + type
            Log.info type, 'ready', t, client.errors.length, client.warnings.length

            compiled = true
            compiled = compiled and client.compiled for client in @clients

            if compiled
                @initialized = true
                t = SW.stop 'compiler.all'
                l = @errors.length
                Log.info 'compiler', 'ready', t, l
                @wz.compiled()
        catch e
            console.log 'compiled error: ', e.toString()
        null




    logErrors: () ->
        base = @cfg.base
        for client in @clients
            if client.warnings.length
                Log.warn client.warnings, base
        for client in @clients
            if client.errors.length
                Log.error client.errors, base
        null




    exit: () ->
        client.exit() for client in @clients
        null


module.exports = Compiler
