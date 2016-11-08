Path  = require 'path'
_     = require 'lodash'
Spawn = require 'cross-spawn'
IPC   = require '../utils/ipc'


options =
    'style':            'nested'
    'stop-on-error':    false
    'sourcemap':        'auto'
    'default-encoding': 'utf-8'
    'check':            true
    'precision':        5
    'cache-location':   ''
    'quiet':            false


class SassWorker


    constructor: () ->
        @initialized = false
        @cfg         = null
        @errors      = null
        @ipc         = new IPC process, @


    init: (@cfg) ->
        options['cache-location'] = Path.join @cfg.base, @cfg.tmp, '.sass-cache'
        null


    compile: (files) ->

        @t      = Date.now()
        @errors = []
        args    = @createCmdArgs files
        sass    = Spawn 'sass', args

        sass.on 'error', (error) =>
            console.log 'sass ERROR: ', error
            @compiled()
            null

        sass.on 'close', (code) =>
            console.log 'sass.close: ', code
            @compiled()
            null

        sass.stdout.on 'data', (data) =>
            console.log 'sass.onData: ', data.toString()
            data = data.toString().split /\\r\\n|\\n/
            for line in data
                error = @getError line
                @errors.push error if error
            null

        sass.stderr.on 'data', (data) =>
            console.log 'sass ERR.DATA: ', data.toString()
            null

        null


    createCmdArgs: (files) ->
        args = []
        for key, value of options
            if key == 'update'
                null
            else if _.isBoolean value
                args.push('--' + key) if value
            else
                if key == 'sourcemap'
                    args.push '--' + key + '=' + value
                else
                    args.push '--' + key
                    args.push value

        if @initialized
            args.push '--update'

        base = @cfg.base
        tmp  = @cfg.tmp
        for file in files
            path = file.path
            if not /^_/.test Path.basename(path)
                out  = Path.join base, tmp, Path.relative(base, path)
                out  = out.replace /\.sass$|\.scss$/, '.css'
                args.push path + ':' + out
        args


    getError: (data) ->
        #console.log data, (/^      error /.test data)
        return null if not /^      error /.test data
        data  = data.substr 12
        end   = data.indexOf ' (Line'
        path  = data.substr 0, end
        error = data.substr end
        return path:path, error:error


    compiled: () ->
        @initialized = true
        @ipc.send 'compiled', 'sass', @errors


instance = new SassWorker()