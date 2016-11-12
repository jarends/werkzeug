FS    = require 'fs'
Path  = require 'path'
_     = require '../utils/pimped-lodash'
FSU   = require '../utils/fsu'
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


class LessCompiler


    constructor: () ->
        @files = {}
        @paths = []
        @ipc   = new IPC(process, @)


    init: (files, @cfg) ->
        console.log 'init lessw'
        options['cache-location'] = Path.join @cfg.base, @cfg.tmp, '.sass-cache'
        files                     = files || []
        @addPath file.path for file in files if files


    addPath: (path) ->
        return null if Path.basename(path)[0] == '_'
        if not @files[path]
            @paths.push path
            @files[path] = version:0
        null


    compileAll: () ->
        t      = Date.now()
        errors = []
        args   = @createCmdArgs @paths
        sass   = Spawn 'sass', args

        sass.on 'error', (error) =>
            console.log 'sass ERROR: ', error
            @ipc.send 'initComplete', errors

        sass.on 'close', (code) =>
            console.log 'sass initialized in ' + (Date.now() - t) + 'ms'
            @ipc.send 'initComplete', errors

        sass.stdout.on 'data', (data) =>
            data = data.toString().split /\\r\\n|\\n/
            for line in data
                error = @getError line
                errors.push error if error
                #console.log 'sass STD.DATA: ', error

        sass.stderr.on 'data', (data) =>
            console.log 'sass ERR.DATA: ', data.toString()

        null


    createCmdArgs: (paths) ->
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

        for path in paths
            out  = Path.join @cfg.base, @cfg.tmp, Path.relative(@cfg.base, path)
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


module.exports = new LessCompiler()