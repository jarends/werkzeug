Path  = require 'path'
FS    = require 'fs-extra'
Sass  = require 'node-sass'
IPC   = require '../utils/ipc'
PH    = require '../utils/path-helper'


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
        options =
            outputStyle: 'compressed'
            sourceMap:   true

        for file in files
            path = file.path
            if not /^_/.test Path.basename(path)
                ++@openFiles
                options.file    = path
                options.outFile = PH.outFromIn @cfg, 'sass', path, true
                Sass.render options, @onResult

        null


    onResult: (error, result) =>

        --@openFiles

        if error
            #console.log 'sass.onError: ', error
            @errors.push
                path: error.file
                line: error.line
                col:  error.column
                text: error.message
        else
            path = result.stats.entry
            out  = PH.outFromIn @cfg, 'sass', path, true
            map  = out + '.map'

            #console.log 'sass write css: ', out

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