Path       = require 'path'
Express    = require 'express'
BodyParser = require 'body-parser'
Portfinder = require 'portfinder'
_          = require 'lodash'
FSU        = require '../utils/fsu'
PH         = require '../utils/path-helper'
IPC        = require '../utils/ipc'
Log        = require '../utils/log'


class Server


    constructor: () ->
        @port = NaN
        @root = null
        @cfg  = null
        @ipc  = new IPC(process, @)


    init: (@cfg) ->
        @root       = PH.getOut @cfg, 'server'
        @express    = Express()
        @express.use BodyParser.json()
        @express.use BodyParser.urlencoded extended:true
        @express.use '/', Express.static @root

        # mod rewrite fake
        @express.get '*', (request, response, next) =>
            path = Path.join @cfg.base, request.path
            if FSU.isFile path
                console.log 'server: path not found (serving relative): ', request.path
                response.sendFile path
            else
                console.log 'server: path not found (serving index.html): ', request.path
                response.sendFile Path.join(@root, '/index.html')

        #TODO: make the port configurable
        Portfinder.basePort = 3001
        Portfinder.getPort (error, port) =>
            if not error
                @port   = port
                @server = @express.listen port, @listeningHandler

        null


    listeningHandler: =>
        @ipc.send 'serverReady', @port
        null


module.exports = new Server()