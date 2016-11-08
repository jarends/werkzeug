CP     = require 'child_process'
SW     = require './utils/stopwatch'
IPC    = require './utils/ipc'
PACKER = __dirname + '/packer/packer'

class Packer


    constructor: (@wz) ->
        @initialized = false
        @cfg         = @wz.cfg
        @packer      = new IPC CP.fork(PACKER), @
        @inited      = false

        @packer.send 'init', @cfg


    pack: (files) ->
        console.log 'pack!!!'
        SW.start 'packer'
        if not @initialized
            @packer.send 'readPackages'
        else
            @packer.send 'update', files
        #setTimeout () => @wz.packed()
        null


    packed: (errors) ->
        console.log "packed in #{SW.stop 'packer'}ms"
        @initialized = true
        @wz.packed()
        null


    exit: () ->
        @packer.exit()


module.exports = Packer
