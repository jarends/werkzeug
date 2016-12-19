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


#TODO: add multiple in and out paths!!!
#TODO: refactor path-helper somehow in cfg!!!

#TODO: add post processors (like autoprefixer)!!!

#TODO: fix errors for empty project!!!

#TODO: refactor error handling -> use info object???

#TODO: fix errors for multiple instances in the same project

#TODO: set ts.noEmitOnError = true and merge packer errors back to compiler errors???

#TODO: make source maps optional!!!

#TODO: enable cli flag for different configs, maybe run configs concurrently

#TODO: watch current wz config and restart app on change

#TODO: remember TREESHAKING for the build process (if it ever comes)???

#TODO: implement salter???




class Werkzeug extends Emitter


    @ignores     = 'node_modules$|\\.DS_Store$|dist$|\\.idea$|\\.git$|gulpfile\\.coffee$|Gruntfile\\.coffee$'
    @interests   = '\\.coffee$|\\.ts$|\\.sass$|\\.scss$|\\.less$|\\.styl$'
    @updateDelay = 500


    constructor: (base, cfg) ->
        super()

        Log()
        Log.info 'werkzeug', 'starting ...'
        Log.startTicker 'werkzeug starting'

        @cfg         = new Config(base, cfg)
        @walker      = new Walker  (@)
        @watcher     = new Watcher (@)
        @compiler    = new Compiler(@)
        @packer      = new Packer  (@) if @cfg.packer.enabled and @cfg.out
        @server      = new Server  (@) if @cfg.server.enabled and @cfg.out
        @builder     = new Builder (@) if @cfg.builder.enabled
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
        return if not @idle or @watcher.watching
        #TODO: make server optional
        @server.init() if @server
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
        @idle     = false
        compiling = @compiler.compile()
        if compiling
            if @initialized
                Log.startTicker 'compiling'
            else
                Log.setTicker 'compiling'

        @cleanFiles()
        @dirty = false

        if not compiling
            @idle = true
            if not @watcher.watching
                @pack()
            else if not @initialized
                @packed()
        null


    compiled: () ->
        @idle = true
        if not @compiler.errors.length
            @pack()
        else
            @packed()
        null


    pack: () ->
        return if not @idle
        @idle = false
        if @packer
            Log.setTicker 'packing'
            @packer.pack @compiler.files
        else
            @packed()
        null


    packed: () ->
        @idle = true
        t     = Log.stopTicker()
        e     = @compiler.errors.concat (@packer?.errors or [])
        el    = e.length
        wl    = @compiler.warnings.length
        w     = @watcher.watching

        @compiler.logErrors()
        @packer.logErrors() if @packer

        if el + wl
            console.log ''

        if not @initialized
            @initialized = true
            s = if w then "startup" else "single run"

        else if @compiler.files and @compiler.files.length
            s = "ready"

        Log.info('werkzeug', s, t, el) if s

        if w
            if @dirty
                @update()
            else if @compiler.files and @compiler.files.length
                now = new Date()
                h   = now.getHours()
                m   = now.getMinutes()
                s   = now.getSeconds()
                h   = '0' + h if h < 10
                m   = '0' + m if m < 10
                s   = '0' + s if s < 10
                Log.info 'werkzeug', 'watching' + ' ... ' + (h + ':' + m + ':' + s + ' - ' + @cfg.base)
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
        #console.log 'fileAdded: ', path
        null


    fileChanged: (path) ->
        file = @fileMap[path]
        return if not file

        file.changed = Date.now()
        file.dirty   = true
        file.errors  = null
        @update()
        #console.log 'fileChanged: ', path
        null


    fileRemoved: (path) ->
        file = @fileMap[path]
        return if not file

        file.removed = Date.now()
        file.dirty   = true
        @update()
        #console.log 'fileRemoved: ', path
        null


    ignore: (path) ->
        @ignores.test path


    interested: (path) ->
        @interests.test path


    terminate: () =>
        Log()
        clearTimeout @updateTimeout
        @compiler.exit()
        @packer.exit() if @packer
        @server.exit() if @server
        process.removeAllListeners()
        setTimeout () -> process.exit 0
        null


module.exports = WZ = Werkzeug
