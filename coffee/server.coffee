Path   = require 'path'
CP     = require 'child_process'
IPC    = require './utils/ipc'
PH     = require './utils/path-helper'
SW     = require './utils/stopwatch'
Log    = require './utils/log'
SERVER = Path.join __dirname, 'server', 'server-process'


class Server


    constructor: (@wz) ->
        @initialized = false
        @cfg         = @wz.cfg
        @port        = NaN


    init: () ->
        SW.start 'server'
        @server.exit() if @server
        @server = new IPC(CP.fork(SERVER), @)
        @server.send 'init', @cfg
        null

    serverReady: (@port) ->
        #root = PH.getOut @cfg, 'server'
        i = ' listening on port '
        p = @port.toString()

        if @port == parseInt @cfg.server.port, 10
            Log Log.prefix('server') + 'ready in ' + Log.ftime('server') + i + p.green
        else
            Log Log.prefix('server') + 'ready in ' + Log.ftime('server') + i + p.red
        null


    exit: () ->
        @server.exit() if @server
        null


module.exports = Server