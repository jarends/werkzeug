Emitter  = require 'events'
FS       = require 'fs'
Path     = require 'path'
FSU      = require './utils/fsu'
SW       = require './utils/stopwatch'
Config   = require './config'
Walker   = require './walker'
Watcher  = require './watcher'
Compiler = require './compiler'
Packer   = require './packer'
Builder  = require './builder'


class Werkzeug extends Emitter

    # TODO: add config paths dynamically
    @ignores     = 'node_modules$|\\.DS_Store$|dist$|\\.idea$|\\.git$|gulpfile\\.coffee$|Gruntfile\\.coffee$|\\.wz\\.tmp$'
    @interests   = '\\.coffee$|\\.ts$|\\.sass$|\\.scss$|\\.less$'
    @updateDelay = 100


    constructor: (base) ->
        super

        SW.start 'startup'

        @cfg         = new Config(base)
        @walker      = new Walker  (@)
        @watcher     = new Watcher (@)
        @compiler    = new Compiler(@)
        @packer      = new Packer  (@)
        @builder     = new Builder (@)
        @ignores     = new RegExp "(#{WZ.ignores})"
        @interests   = new RegExp "(#{WZ.interests})"
        @current     = []
        @files       = []
        @fileMap     = {}
        @idle        = true
        @initialized = false
        @dirty       = false

        # TODO: append @cfg paths to ignores (dest, tmp, ...)

        tmp = Path.join @cfg.base, @cfg.tmp
        FSU.rmDir tmp if FSU.isDir tmp
        FS.mkdirSync tmp
        process.on 'exit',    @terminate
        process.on 'SIGINT',  @terminate
        process.on 'SIGTERM', @terminate


    watch: () ->
        return if not @idle || @watcher.watching
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
        SW.start 'update'
        @current = @compiler.compile()
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
        @packer.pack(@current)
        null


    packed: () ->
        @idle = true
        if not @initialized
            @initialized = true
            console.log "startup in #{SW.stop 'startup'}ms"
        else
            console.log "update in #{SW.stop 'update'}ms"

        if @watcher.watching
            if @dirty
                @update()
            else
                console.log 'start watching ...'
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
        null


    fileAdded: (path) ->
        file = @fileMap[path]
        if file
            file.removed = false
        else
            @files.push(file = @fileMap[path] = {})

        #console.log 'fileAdded: ', path

        file.path  = path
        file.added = Date.now()
        file.dirty = true
        @update()
        null


    fileChanged: (path) ->
        file = @fileMap[path]
        return if not file

        #console.log 'fileChanged: ', path

        file.changed = Date.now()
        file.dirty   = true
        @update()
        null


    fileRemoved: (path) ->
        file = @fileMap[path]
        return if not file

        #console.log 'fileRemoved: ', path

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
        process.removeAllListeners()
        setTimeout () -> process.exit 0
        null


module.exports = WZ = Werkzeug
