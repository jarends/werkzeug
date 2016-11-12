Walk  = require 'walkdir'
EMap  = require 'emap'


options =
    follow_symlinks: false
    no_recurse:      false
    max_depth:       undefined


class Walker


    constructor: (@wz) ->
        @cfg     = @wz.cfg
        @options = options
        @emap    = new EMap()


    walk: () ->
        console.log 'walk'
        if @w
            @w.end()
            @emap.all()

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
        @wz.walked()
        null


module.exports = Walker