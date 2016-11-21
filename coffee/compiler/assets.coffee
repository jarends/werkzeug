FSE = require 'fs-extra'
FSU = require '../utils/fsu'
PH  = require '../utils/path-helper'
IPC = require '../utils/ipc'
Log = require '../utils/log'


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
        for file in files
            ++@openFiles
            path = file.path
            if not file.removed
                @copy path
            else
                @remove path

        @compiled() if @openFiles == 0
        null


    copy: (path) ->
        out = PH.outFromIn @cfg, 'assets', path
        FSE.copy path, out, (error) =>
            @errors.push {path:path, error:error} if error
            @compiled() if --@openFiles == 0
            null
        null


    remove: (path, out) ->
        out = PH.outFromIn @cfg, null, path, true
        map = out + '.map'

        FSE.remove out, (error) =>
            if FSU.isFile map
                ++@openFiles
                FSE.remove map, (error) =>
                    @errors.push {path:map, error:error} if error
                    @compiled() if --@openFiles == 0
                    null

            @errors.push {path:out, error:error} if error
            @compiled() if --@openFiles == 0
            null
        null


    compiled: () ->
        #console.log 'assets.compiled!!!'
        @ipc.send 'compiled', 'assets', @errors


module.exports = new AssetCompiler()