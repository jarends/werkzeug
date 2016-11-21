Emitter  = require 'events'
FS       = require 'fs'
Path     = require 'path'
Config   = require './config'
Server   = require './server'
Walker   = require './walker'
Watcher  = require './watcher'
Compiler = require './compiler'
Packer   = require './packer'
Builder  = require './builder'
FSU      = require './utils/fsu'
PH       = require './utils/path-helper'
Log      = require('./utils/log').mapLogs()


#TODO: set ts.noEmitOnError = true and merge packer errors back to compiler errors!!!

#TODO: make sourcemaps optional

#TODO: implement salter!!!

#TODO: enable cli flag for different configs, maybe run configs concurrently
# .wz.prod -> wz prod
# .wz.dev  -> wz dev

#TODO: watch current wz config and restart app on change

#TODO: implement reasonable config params

#TODO: maybe implement globs for config paths




class Werkzeug extends Emitter


    @ignores     = 'node_modules$|\\.DS_Store$|dist$|\\.idea$|\\.git$|gulpfile\\.coffee$|Gruntfile\\.coffee$'
    @interests   = '\\.coffee$|\\.ts$|\\.sass$|\\.scss$|\\.less$|\\.styl$'
    @updateDelay = 500


    constructor: (base) ->
        super

        Log.info 'werkzeug', 'starting ...'
        Log.startTicker 'werkzeug starting'

        @cfg         = new Config(base)
        @server      = new Server  (@)
        @walker      = new Walker  (@)
        @watcher     = new Watcher (@)
        @compiler    = new Compiler(@)
        @packer      = new Packer  (@)
        @builder     = new Builder (@)
        @errors      = []
        @files       = []
        @fileMap     = {}
        @idle        = true
        @initialized = false
        @dirty       = false

        # clear all output paths and add them to ignores
        paths = PH.getPaths(@cfg)
        for path in paths
            FSU.rmDir path if FSU.isDir path
            FS.mkdirSync path

            ignore = Path.relative @cfg.base, path
            ignore = ignore.replace(/\\/g, '\\\\').replace(/\//g, '\\/').replace(/\./g, '\\.') + '$'
            WZ.ignores += '|' + ignore

        @ignores   = new RegExp("(#{WZ.ignores})")
        @interests = new RegExp("(#{WZ.interests})")

        process.on 'exit',    @terminate
        process.on 'SIGINT',  @terminate
        process.on 'SIGTERM', @terminate


    watch: () ->
        return if not @idle || @watcher.watching
        #TODO: make server optional
        @server.init()
        @watcher.watch()
        null


    walk: () ->
        return if not @idle
        @idle = false
        @walker.walk()
        null


    walked: () ->
        @idle = true
        @compile()
        null


    compile: () ->
        return if not @idle
        @idle = false
        if @initialized
            Log.startTicker 'compiling'
        else
            Log.setTicker 'compiling'
        @compiler.compile()
        @cleanFiles()
        @dirty = false
        null


    compiled: () ->
        @idle = true
        @pack()
        null


    pack: () ->
        return if not @idle
        @idle = false
        Log.setTicker 'packing'
        @packer.pack(@compiler.files)
        null


    packed: () ->
        @idle = true
        time  = Log.stopTicker()

        if not @initialized
            @initialized = true
            if @watcher.watching
                Log.info 'werkzeug', "startup in #{Log.ftime time}"
            else
                Log.info 'werkzeug', "single run in #{Log.ftime time}"

        else if @compiler.files and @compiler.files.length
            Log.info 'werkzeug', "updated in #{Log.ftime time}"

        if @watcher.watching
            if @dirty
                @update()
            else if @compiler.files and @compiler.files.length
                Log.info 'werkzeug', 'start watching ...'
        else
            @terminate()
        null


    update: () ->
        @dirty = true
        return if not @idle or not @initialized
        clearTimeout @updateTimeout
        @updateTimeout = setTimeout @updateNow, WZ.updateDelay
        null


    updateNow: () =>
        return if not @idle
        @compile()
        null


    cleanFiles: () ->
        @errors = []
        for path, file of @fileMap
            if file.dirty
                if file.removed
                    index = @files.indexOf file
                    @files.splice index, 1 if index > -1
                    delete @fileMap[file.path]
                else
                    file.dirty   = false
                    file.added   = false
                    file.changed = false
                    file.errors  = null
        null


    fileAdded: (path) ->
        file = @fileMap[path]
        if file
            file.removed = false
        else
            @files.push(file = @fileMap[path] = {})

        file.path   = path
        file.added  = Date.now()
        file.dirty  = true
        file.errors = null
        @update()
        null


    fileChanged: (path) ->

        file = @fileMap[path]
        return if not file

        file.changed = Date.now()
        file.dirty   = true
        file.errors  = null
        @update()
        null


    fileRemoved: (path) ->
        file = @fileMap[path]
        return if not file

        file.removed = Date.now()
        file.dirty   = true
        @update()
        null


    ignore: (path) ->
        @ignores.test path


    interested: (path) ->
        @interests.test path


    terminate: () =>
        console.log '\rterminate'
        clearTimeout @updateTimeout
        @compiler.exit()
        @packer.exit()
        @server.exit()
        process.removeAllListeners()
        setTimeout () -> process.exit 0
        null


module.exports = WZ = Werkzeug
