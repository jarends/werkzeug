Path   = require 'path'
CP     = require 'child_process'
SW     = require './utils/stopwatch'
IPC    = require './utils/ipc'
Log    = require './utils/log'
PACKER = Path.join __dirname, 'packer', 'packer-process'


class Packer


    constructor: (@wz) ->
        @info        = null
        @errors      = []
        @initialized = false
        @cfg         = @wz.cfg
        @packer      = new IPC(CP.fork(PACKER), @)

        @packer.send 'init', @cfg


    pack: (files) ->
        if files and files.length
            Log.info 'packer', 'starting'.white + ' ...'
            SW.start 'packer'
            if not @initialized
                @packer.send 'readPackages'
            else
                @packer.send 'update', files
        else
            @wz.packed()
        null


    packFiles: () ->
        null


    packed: (@info) ->
        @initialized = true
        @errors      = @info.errors
        t            = SW.stop 'packer'
        l            = @errors.length
        Log.info 'packer', 'ready', t, l

        #console.log 'packer.info: ', @info

        @wz.packed()
        null


    exit: () ->
        @packer.exit()
        null


module.exports = Packer
