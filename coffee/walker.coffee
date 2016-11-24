Walk = require 'walkdir'
EMap = require 'emap'
Log  = require './utils/log'
SW   = require './utils/stopwatch'


options =
    follow_symlinks: true
    no_recurse:      false
    max_depth:       50


class Walker


    constructor: (@wz) ->
        @cfg     = @wz.cfg
        @options = options
        @emap    = new EMap()


    walk: () ->
        if @w
            @w.end()
            @emap.all()

        SW.start 'walker'
        @w = Walk @cfg.base, @options

        @emap.map @w, 'path', @pathHandler, @
        @emap.map @w, 'end',  @endHandler,  @
        null


    pathHandler: (path, stat) ->
        ignore = @wz.ignore path
        if stat.isDirectory()
            @w.ignore path if ignore
        else if not ignore
            @wz.fileAdded path
        null


    endHandler: () ->
        Log.info 'walker', 'ready', SW.stop 'walker', 0
        @wz.walked()
        null


module.exports = Walker