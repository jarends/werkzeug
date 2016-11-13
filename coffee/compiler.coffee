Path   = require 'path'
CP     = require 'child_process'
IPC    = require './utils/ipc'
SW     = require './utils/stopwatch'
PH     = require './utils/path-helper'
TS     = Path.join __dirname, 'compiler', 'ts'
ASSET  = Path.join __dirname, 'compiler', 'assets'
SASS   = Path.join __dirname, 'compiler', 'sass'
#TODO: use a generalized compiler contruct

class Compiler


    constructor: (@wz) ->
        @cfg    = @wz.cfg
        @ts     = ipc: new IPC(CP.fork(TS),    @), compiled: false
        @sass   = ipc: new IPC(CP.fork(SASS),  @), compiled: false
        @assets = ipc: new IPC(CP.fork(ASSET), @), compiled: false

        @ts.ipc.send     'init', @cfg
        @sass.ipc.send   'init', @cfg
        @assets.ipc.send 'init', @cfg


    compile: () ->
        ts        = []
        sass      = []
        assets    = []

        tsRoot    = PH.getIn @cfg, 'ts'
        sassRoot  = PH.getIn @cfg, 'sass'
        assetRoot = PH.getIn @cfg, 'assets'

        @ts.compiled     = false
        @sass.compiled   = false
        @assets.compiled = false

        SW.start 'compiler.ts'
        SW.start 'compiler.sass'
        SW.start 'compiler.assets'
        SW.start 'compiler.all'

        @errors = []
        @files  = []

        for file in @wz.files

            if file.dirty or file.errors
                path    = file.path
                removed = file.removed
                used    = false

                f = path:path, removed:removed, error:false

                # add removed files also to update ts file map
                if PH.testTS(path) and path.indexOf(tsRoot) == 0
                    ts.push f
                    used = true
                # ignore removed files
                else if PH.testSass(path) and not removed and path.indexOf(sassRoot) == 0
                    sass.push f
                    used = true
                # ignore removed files in this else -> all remoed will be added separate
                else if path.indexOf(assetRoot) == 0 and not removed
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
            @assets.compiled = true;

        if sass.length
            @sass.ipc.send 'compile', sass
        else
            @sass.compiled = true

        if ts.length
            @ts.ipc.send 'compile', ts
        else
            @ts.compiled = true

        l = @files.length
        if l
            console.log "start compiling... (#{l} #{if l > 1 then 'files' else 'file'})".cyan
        else
            @wz.compiled()

        null




    compiled: (comp, errors) ->
        @[comp].compiled = true

        for error in errors
            @errors.push error
            path        = error.path
            file        = @wz.fileMap[path]
            if file
                file.errors = true
            #TODO: handle error somehow
            else
                #console.log 'error in file, but file not in root: ', path

        t = SW.stop 'compiler.' + comp
        l = errors.length
        if l > 0
            console.log "#{comp} compiled in #{t}ms with #{errors.length} #{if l > 1 then 'errors' else 'error'}".red
        else
            console.log "#{comp} compiled in #{t}ms without errors".green

        if @ts.compiled and @sass.compiled and @assets.compiled
            t = SW.stop 'compiler.all'
            l = @errors.length
            if @errors.length > 0
                console.log "all compiled in #{t}ms with #{l} #{if l > 1 then 'errors' else 'error'}".red
            else
                console.log "all compiled in #{t}ms without errors".green

            @wz.compiled()

        null




    exit: () ->
        @ts.ipc.exit()
        @sass.ipc.exit()
        @assets.ipc.exit()
        null


module.exports = Compiler
