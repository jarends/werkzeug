# fix some stylus problems
require './stylus-fixes'

Stylus = require 'stylus'
FS     = require 'fs'
FSE    = require 'fs-extra'
Path   = require 'path'
PH     = require '../utils/path-helper'
IPC    = require '../utils/ipc'
Log    = require '../utils/log'




class StylusCompiler


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
                    path:  path
                    error: 'file read error'
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
                        @errors.push
                            path:  path
                            line:  error.lineno
                            col:   error.column + 1
                            error: error.text
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
        @initialized = true
        @ipc.send 'compiled', 'styl', @errors


module.exports = new StylusCompiler()