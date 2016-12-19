Emitter = require 'events'
EMap    = require 'emap'
_       = require '../utils/pimped-lodash'
Log     = require '../utils/log'
Process = process

class IPC extends Emitter


    constructor: (process, @owner) ->
        @emap    = new EMap()
        @process = process

        @emap.map process, 'message',    @messageHandler,    @
        #TODO: react to events - maybe restart forked process or entire app
        @emap.map process, 'close',      @closeHandler,      @
        @emap.map process, 'disconnect', @disconnectHandler, @
        @emap.map process, 'error',      @errorHandler,      @
        @emap.map process, 'exit',       @exitHandler,       @

        if process == Process
            console.log = @log
            Log.log     = @log
            Log.console = @

        null


    send: (type, args...) ->
        return null if not @process or not @process.connected
        @process.send
            type: type
            args: args
        null


    exit: () ->
        @process.kill() if @process


    log: (args...) =>
        return null if not @process or not @process.connected
        @process.send
            type: 'ipc.log'
            args: args
        null


    messageHandler: (message) ->
        type = message?.type
        return null if not type
        args = message.args or []
        return null if not _.isArray args

        if type == 'ipc.log'
            Log.apply null, args

        else if @owner and _.isFunction @owner[type]
            try
                @owner[type].apply @owner, args

            #TODO: handle error - maybe restart forked process or entire app
            catch e
                console.log "IPC ERROR: can not handle type '#{type}' for owner '#{@owner}!': ", e.toString(), e.stack

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