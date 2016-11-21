Less = require 'less'
FS   = require 'fs'
FSE  = require 'fs-extra'
Path = require 'path'
PH   = require '../utils/path-helper'
IPC  = require '../utils/ipc'
Log  = require '../utils/log'




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
                outPath = PH.outFromIn @cfg, 'less', path, true
                mapPath = outPath + '.map'
                options =
                    filename: Path.relative Path.dirname(outPath), path
                    compress: true
                    sourceMap:
                        sourceMapURL:        Path.basename mapPath
                        sourceMapBasepath:   ''
                        sourceMapRootpath:   ''
                        outputSourceFiles:   false
                        sourceMapFileInline: false

                Less.render source, options, (error, result) =>
                    ++@openFiles
                    if error
                        @errors.push
                            path: error.filename
                            line: error.line
                            col:  error.column + 1
                            text: error.message
                    else
                        cssSrc = result.css
                        mapSrc = result.map

                        if mapSrc
                            FSE.ensureFileSync mapPath
                            FS.writeFileSync mapPath, mapSrc, 'utf8'

                        FSE.ensureFileSync outPath
                        FS.writeFileSync outPath, cssSrc, 'utf8'

                    @compiled() if --@openFiles == 0

            @compiled() if --@openFiles == 0
            null


    compiled: () ->

        if @errors.length
            console.log 'less errors: ', @errors

        @initialized = true
        @ipc.send 'compiled', 'less', @errors


module.exports = new LessCompiler()