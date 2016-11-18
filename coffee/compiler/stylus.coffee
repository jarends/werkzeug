# fix some stylus problems
require './stylus-fixes'

Stylus  = require 'stylus'
FS      = require 'fs'
FSE     = require 'fs-extra'
Path    = require 'path'
IPC     = require '../utils/ipc'
PH      = require '../utils/path-helper'




class LessCompiler


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
        path = file.path
        ++@openFiles

        FS.readFile path, 'utf8', (error, source) =>
            if error
                @errors.push
                    path: path
                    line: 0
                    col:  0
                    text: 'file read error'
            else
                outPath = PH.outFromIn @cfg, 'styl', path, true
                mapPath = outPath + '.map'
                options =
                    filename: outPath
                    compress: true
                    sourcemap:
                        basePath:   ''
                        sourceRoot: ''
                        comment:    false
                        inline:     false

                style = Stylus(source, options)

                style.render (error, cssSrc) =>
                    ++@openFiles
                    if error
                        console.log 'styl.error:\n', error
                        @errors.push
                            path: path
                            line: error.lineno
                            col:  error.column + 1
                            text: error.text
                    else
                        mapSrc = style.sourcemap
                        if mapSrc
                            cssSrc        += "\n/*# sourceMappingURL=#{Path.basename mapPath} */\n"
                            mapSrc.sources = [Path.relative Path.dirname(outPath), path]
                            FSE.ensureFileSync mapPath
                            FS.writeFileSync mapPath, JSON.stringify(mapSrc), 'utf8'

                        FSE.ensureFileSync outPath
                        FS.writeFileSync outPath, cssSrc, 'utf8'

                    @compiled() if --@openFiles == 0

            @compiled() if --@openFiles == 0
            null


    compiled: () ->

        if @errors.length
            console.log 'stylus errors: ', @errors

        @initialized = true
        @ipc.send 'compiled', 'styl', @errors


module.exports = new LessCompiler()