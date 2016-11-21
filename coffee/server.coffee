Path   = require 'path'
CP     = require 'child_process'
IPC    = require './utils/ipc'
PH     = require './utils/path-helper'
Log    = require './utils/log'
SERVER = Path.join __dirname, 'server', 'server-process'


class Server


    constructor: (@wz) ->
        @initialized = false
        @cfg         = @wz.cfg


    init: () ->
        @server.exit() if @server
        @server = new IPC(CP.fork(SERVER), @)
        @server.send 'init', @cfg
        null

    serverReady: (port) ->
        #root = PH.getOut @cfg, 'server'
        Log.info 'server', "listening on port #{port}"
        null


    exit: () ->
        @server.exit() if @server
        null


module.exports = Server