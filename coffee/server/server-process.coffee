Path       = require 'path'
Express    = require 'express'
BodyParser = require 'body-parser'
Portfinder = require 'portfinder'
IPC        = require '../utils/ipc'
PH         = require '../utils/path-helper'


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

        console.log 'server serving from: ', @root

        # mod rewrite fake
        @express.get '*', (request, response, next) =>
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