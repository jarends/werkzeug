Path  = require 'path'
FS    = require 'fs-extra'
Sass  = require 'node-sass'
Reg   = require '../utils/regex'
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


class SassCompiler


    constructor: () ->
        @initialized = false
        @cfg         = null
        @errors      = null
        @openFiles   = 0
        @ipc         = new IPC process, @


    init: (@cfg) ->
        options['cache-location'] = Path.join @cfg.base, @cfg.tmp, '.sass-cache'
        null


    compile: (files) ->

        @errors = []
        options =
            outputStyle: 'compressed'
            sourceMap:   true

        base = @cfg.base
        tmp  = @cfg.tmp
        for file in files
            path = file.path
            if not /^_/.test Path.basename(path)
                ++@openFiles
                out             = Path.join base, tmp, Path.relative(base, path)
                options.file    = path
                options.outFile = Reg.correctOut out
                Sass.render options, @onResult

        null


    onResult: (error, result) =>

        --@openFiles

        if error
            console.log 'sass.onError: ', error
        else
            #console.log 'sass.onResult: ', @openFiles, result

            base = @cfg.base
            tmp  = @cfg.tmp
            path = result.stats.entry
            out  = Path.join base, tmp, Path.relative(base, path)
            out  = Reg.correctOut(out)
            map  = out + '.map'

            FS.ensureFileSync out
            FS.ensureFileSync map
            FS.writeFileSync out, result.css, 'utf8'
            FS.writeFileSync map, result.map, 'utf8'

        if @openFiles == 0
            @compiled()
        null


    compiled: () ->
        #console.log 'sass.compiled!!!'
        @initialized = true
        @ipc.send 'compiled', 'sass', @errors


module.exports = new SassCompiler()