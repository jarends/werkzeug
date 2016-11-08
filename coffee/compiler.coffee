Path   = require 'path'
CP     = require 'child_process'
IPC    = require './utils/ipc'
Reg    = require './utils/regex'
SW     = require './utils/stopwatch'
TSW    = Path.join __dirname, 'compiler', 'ts'
ASSETW = Path.join __dirname, 'compiler', 'assets'
SASSW  = Path.join __dirname, 'compiler', 'sass'


class Compiler


    constructor: (@wz) ->
        @cfg     = @wz.cfg
        @ts      = ipc: new IPC(CP.fork(TSW),    @), compiled: false
        @sass    = ipc: new IPC(CP.fork(SASSW),  @), compiled: false
        @assets  = ipc: new IPC(CP.fork(ASSETW), @), compiled: false

        @ts.ipc.send     'init', @cfg
        @sass.ipc.send   'init', @cfg
        @assets.ipc.send 'init', @cfg


    compile: () ->
        console.log "compile #{@wz.files.length} files"

        current = []
        ts      = []
        sass    = []
        assets  = []
        root    = Path.join @cfg.base, @cfg.root

        @ts.compiled     = false
        @sass.compiled   = false
        @assets.compiled = false

        SW.start 'ts'
        SW.start 'sass'
        SW.start 'assets'
        SW.start 'total'

        for file in @wz.files
            if file.dirty

                #console.log 'compiler handle file: ', file.path

                path    = file.path
                removed = file.removed
                used    = false

                # add removed files also to update ts file map
                if Reg.testTS(path)
                    ts.push file
                    used = true
                # ignore removed files
                else if Reg.testSass(path) and not removed
                    sass.push file
                    used = true
                # ignore removed files in this else -> all remoed will be added separate
                else if path.indexOf(root) == 0 and not removed
                    assets.push file
                    used = true

                # add all removed to assets
                if removed
                    assets.push file
                    used = true

                if used
                    current.push path:file.path, removed:file.removed

        #console.log 'compile assets: ', assets.length
        if assets.length
            @assets.ipc.send 'compile', assets
        else
            @assets.compiled = true;

        #console.log 'compile sass: ', sass.length
        if sass.length
            @sass.ipc.send 'compile', sass
        else
            @sass.compiled = true

        #console.log 'compile ts: ', ts.length
        if ts.length
            @ts.ipc.send 'compile', ts
        else
            @ts.compiled = true

        current


    compiled: (comp, errors) ->
        console.log "#{comp} compiled in #{SW.stop comp}ms #{if errors and errors.length then 'with ' + errors.length + ' errors' else 'without errors'}", errors
        @[comp].compiled = true
        if @ts.compiled && @sass.compiled and @assets.compiled
            console.log "total compile time: #{SW.stop 'total'}ms "
            @wz.compiled()
        null



    exit: () ->
        @ts.ipc.exit()
        @sass.ipc.exit()
        @assets.ipc.exit()
        null


module.exports = Compiler
