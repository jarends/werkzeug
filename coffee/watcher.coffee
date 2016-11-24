Chok = require 'chokidar'
EMap = require 'emap'
Log  = require './utils/log'
SW   = require './utils/stopwatch'


class Watcher

    constructor: (@wz) ->
        @cfg  = @wz.cfg
        @emap = new EMap()


    watch: () ->
        if @watcher
            @emap.all()
            @watcher.close()

        SW.start 'watcher'
        @watcher = Chok.watch @cfg.base,
            ignored:       [@wz.ignores]
            ignoreInitial: false
            usePolling:    false
            useFsEvents:   true

        @emap.map @watcher, 'add',    @addedHandler,    @
        @emap.map @watcher, 'change', @changedHandler,  @
        @emap.map @watcher, 'unlink', @unlinkedHandler, @
        @emap.map @watcher, 'ready',  @readyHandler,    @
        null


    addedHandler: (path) ->
        @wz.fileAdded path
        null


    changedHandler: (path) ->
        @wz.fileChanged path
        null


    unlinkedHandler: (path) ->
        @wz.fileRemoved path
        null


    readyHandler: () ->
        Log.info 'watcher', 'ready', SW.stop 'watcher', 0
        @watching = true
        @wz.walked()
        null


module.exports = Watcher
