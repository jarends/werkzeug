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
        packs = @cfg.packer.packages
        if files and files.length and packs and packs.length
            Log.info 'packer', 'starting ...'
            SW.start 'packer'
            if not @initialized
                @packer.send 'readPackages'
            else
                @packer.send 'update', files
        else
            @wz.packed()
        null


    packed: (@info) ->
        @initialized = true
        @errors      = @info.errors
        t            = SW.stop 'packer'
        l            = @errors.length
        Log.info 'packer', 'ready', t, l

        @wz.packed()
        null


    logErrors: () ->
        try
            base = @cfg.base
            if @errors.length
                for error in @errors
                    error.type = 'packer'
                Log.error @errors, base
        catch e
            console.log 'packing error: ', e.toString()
        null


    exit: () ->
        @packer.exit()
        null


module.exports = Packer
