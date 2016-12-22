Path = require 'path'
FSE  = require 'fs-extra'
FS   = require 'fs'
Sass = null
_    = require '../utils/pimped-lodash'
PH   = require '../utils/path-helper'
IPC  = require '../utils/ipc'
Log  = require '../utils/log'


class SassCompiler


    constructor: () ->
        @initialized = false
        @cfg         = null
        @errors      = null
        @openFiles   = 0
        @ipc         = new IPC(process, @)

        console.log 'sass constructor: ', process.versions

        try
            Sass = require 'node-sass'
        catch e
            console.log 'SAS require ERROR: ', e.toString(), e. stack


    init: (@cfg) ->
        @inPath  = PH.getIn  @cfg, 'sass'
        @outPath = PH.getOut @cfg, 'sass'
        null


    compile: (files) ->
        @errors  = []
        compiled = {}
        for file in files
            compiled[file.path] = true
            @compileFile file

        globals = @cfg.sass.globals or []
        for path in globals
            path = Path.join @inPath, path
            @compileFile(path:path) if not compiled[path]

        @compiled() if @openFiles == 0
        null


    compileFile: (file) ->
        path    = file.path
        options =
            outputStyle: 'compressed'
            sourceMap:   true

        if not /^_/.test Path.basename(path)
            ++@openFiles
            options.file    = path
            options.outFile = PH.outFromIn @cfg, 'sass', path, true
            Sass.render options, @onResult
        null


    onResult: (error, result) =>
        if error
            @errors.push
                path:  error.file or result?.stats?.entry or 'file missing'
                line:  error.line
                col:   error.column
                error: error.message
        else
            path = result.stats.entry
            out  = PH.outFromIn @cfg, 'sass', path, true
            map  = out + '.map'

            FSE.ensureFileSync out
            FSE.ensureFileSync map
            FS.writeFileSync out, result.css, 'utf8'
            FS.writeFileSync map, result.map, 'utf8'

        @compiled() if --@openFiles == 0
        null


    compiled: () ->
        @initialized = true
        @ipc.send 'compiled', 'sass', @errors


module.exports = new SassCompiler()