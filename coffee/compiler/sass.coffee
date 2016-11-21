Path = require 'path'
FSE  = require 'fs-extra'
FS   = require 'fs'
Sass = require 'node-sass'
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


    init: (@cfg) ->
        null


    compile: (files) ->
        @errors = []
        for file in files
            @compileFile file
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
                path: error.file
                line: error.line
                col:  error.column
                text: error.message
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