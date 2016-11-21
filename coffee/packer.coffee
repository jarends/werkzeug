Path   = require 'path'
CP     = require 'child_process'
SW     = require './utils/stopwatch'
IPC    = require './utils/ipc'
Log    = require './utils/log'
PACKER = Path.join __dirname, 'packer', 'packer-process'


class Packer


    constructor: (@wz) ->
        @initialized = false
        @cfg         = @wz.cfg
        @packer      = new IPC(CP.fork(PACKER), @)

        @packer.send 'init', @cfg


    pack: (files) ->
        if files and files.length
            Log.info 'packer', "starting ..."
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


    packed: (errors) ->
        t = SW.stop 'packer'
        l = errors.length

        if l > 0
            e = "#{l} #{Log.count l, 'error'}".red
            Log.info 'packer', "packed in #{Log.ftime t} with #{e}", errors
        else
            Log.info 'packer', "packed in #{Log.ftime t} #{Log.ok}"

        @initialized = true
        @errors      = errors
        @wz.packed()
        null


    exit: () ->
        @packer.exit()
        null


module.exports = Packer
