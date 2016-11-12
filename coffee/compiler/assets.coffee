FS    = require 'fs-extra'
Path  = require 'path'
Reg   = require '../utils/regex'
FSU   = require '../utils/fsu'
IPC   = require '../utils/ipc'


class AssetCompiler


    constructor: () ->
        @cfg       = null
        @errors    = null
        @openFiles = 0
        @ipc       = new IPC(process, @)


    init: (@cfg) ->
        null


    compile: (files) ->
        @errors    = []
        @openFiles = 0
        base       = @cfg.base
        tmp        = Path.join base, @cfg.tmp
        for file in files
            ++@openFiles
            path = file.path
            out  = Path.join tmp, Path.relative(base, path)
            if not file.removed
                @copy path, out
            else
                @remove path, out

        if not @openFiles
            @compiled()
        null


    copy: (path, out) ->
        #console.log 'copy asset: ', path
        FS.copy path, out, (error) =>
            --@openFiles
            @errors.push {path:path, error:error} if error
            @compiled() if @openFiles == 0
            null
        null


    remove: (path, out) ->
        #console.log 'remove asset: ', path
        out = Reg.correctOut out
        map = out + '.map'

        FS.remove out, (error) =>
            --@openFiles
            FS.removeSync(map) if FSU.isFile map
            @errors.push {path:path, error:error} if error
            @compiled() if @openFiles == 0
            null
        null


    compiled: () ->
        #console.log 'assets.compiled!!!'
        @ipc.send 'compiled', 'assets', @errors


module.exports = new AssetCompiler()