Coffee = require 'coffee-script'
FS     = require 'fs'
FSE    = require 'fs-extra'
Path   = require 'path'
PH     = require '../utils/path-helper'
IPC    = require '../utils/ipc'
Log    = require '../utils/log'



class CoffeeCompiler


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
        ++@openFiles

        FS.readFile path, 'utf8', (error, source) =>
            if error
                @errors.push
                    path: path
                    error: 'file read error'
            else

                outPath = PH.outFromIn @cfg, 'coffee', path, true
                mapPath = outPath + '.map'
                options =
                    sourceMap:   true
                    filename:    path
                    generatedFile: Path.basename outPath
                    sourceRoot:  ''
                    sourceFiles: [Path.relative Path.dirname(outPath), path]

                try
                    result = Coffee.compile source, options
                catch error

                if error
                    text = /error: (.*?)(\r\n|\n)/.exec(error.toString())
                    text = text[1] if text
                    text = text or error.toString()
                    @errors.push
                        path:  error.filename
                        line:  error.location.first_line   + 1
                        col:   error.location.first_column + 1
                        error: text
                else
                    jsSrc   = result.js
                    mapSrc  = result.v3SourceMap

                    if mapSrc
                        jsSrc      += "\n//# sourceMappingURL=#{Path.basename mapPath}\n"
                        FSE.ensureFileSync mapPath
                        FS.writeFileSync mapPath, mapSrc, 'utf8'

                    FSE.ensureFileSync outPath
                    FS.writeFileSync outPath, jsSrc, 'utf8'

            @compiled() if --@openFiles == 0
            null


    compiled: () ->
        @initialized = true
        @ipc.send 'compiled', 'coffee', @errors


module.exports = new CoffeeCompiler()