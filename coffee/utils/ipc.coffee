Emitter = require 'events'
EMap    = require 'emap'
_       = require 'lodash'


class IPC extends Emitter


    @isChild = () -> process.send and not module.parent


    constructor: (process, @owner) ->
        @emap   = new EMap()
        @sync   = false
        @result = null
        @init process, @owner if process


    init: (process, @owner) ->
        @emap.all() if @process
        @process = process
        @emap.map process, 'message',    @messageHandler,    @
        @emap.map process, 'close',      @closeHandler,      @
        @emap.map process, 'disconnect', @disconnectHandler, @
        @emap.map process, 'error',      @errorHandler,      @
        @emap.map process, 'exit',       @exitHandler,       @
        null


    send: (type, args...) ->
        return null if not @process or not @process.connected
        @process.send
            type: type
            args: args
        null


    exit: () ->
        @process.kill() if @process



    messageHandler: (message) ->
        type = message?.type
        return null if not type
        args = message.args || []
        return null if not _.isArray args

        if @owner and _.isFunction @owner[type]
            try
                @owner[type].apply @owner, args
            catch e
                console.log "IPC ERROR: can not handle type '#{type}' for owner '#{@owner}': ", e

        if @listenerCount type
            args = args.concat()
            args.unshift(type)
            @emit.apply @, args
        null


    closeHandler: () ->
        #console.log 'process close'
        null


    disconnectHandler: () ->
        #console.log 'process disconnect'
        null


    errorHandler: () ->
        #console.log 'process error'
        null


    exitHandler: () ->
        #console.log 'process exit'
        null


module.exports = IPC