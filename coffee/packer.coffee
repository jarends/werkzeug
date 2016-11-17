Path   = require 'path'
CP     = require 'child_process'
SW     = require './utils/stopwatch'
IPC    = require './utils/ipc'
PACKER = Path.join __dirname, 'packer', 'packer-process'


class Packer


    constructor: (@wz) ->
        @initialized = false
        @cfg         = @wz.cfg
        @packer      = new IPC(CP.fork(PACKER), @)

        @packer.send 'init', @cfg


    pack: (files) ->
        if files and files.length
            console.log "start packing...".cyan
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
            console.log "packed in #{t}ms with #{l} #{if l > 1 then 'errors' else 'error'}".red, errors
        else
            console.log "packed in #{t}ms without errors".green

        @initialized = true
        @errors      = errors
        @wz.packed()
        null


    exit: () ->
        @packer.exit()
        null


module.exports = Packer
