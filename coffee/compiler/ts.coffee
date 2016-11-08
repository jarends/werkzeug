ts   = require 'typescript'
FS   = require 'fs-extra'
Path = require 'path'
FSU  = require '../utils/fsu'
IPC  = require '../utils/ipc'


options =
    target:                         ts.ScriptTarget.ES5
    module:                         ts.ModuleKind.CommonJS
    moduleResolution:               ts.ModuleResolutionKind.NodeJs
    rootDir:                        ''
    outDir:                         ''
    sourceMap:                      true
    emitBOM:                        false
    experimentalDecorators:         true
    emitDecoratorMetadata:          true
    allowSyntheticDefaultImports:   true
    removeComments:                 false
    noImplicitAny:                  false
    noEmit:                         false
    noEmitOnError:                  false
    preserveConstEnums:             true
    suppressImplicitAnyIndexErrors: true


class TSCompiler

    constructor: () ->
        @initialized = false
        @cfg         = null
        @errors      = null
        @files       = {}
        @paths       = []
        @ipc         = new IPC process, @


    init: (@cfg) ->
        options.outDir  = Path.join @cfg.base, @cfg.tmp
        options.rootDir = @cfg.base
        null


    addPath: (path) ->
        file = @files[path]
        if not file
            @paths.push path
            @files[path] = version:0
        else
            ++file.version
        null


    removePath: (path) ->
        if @files[path]
            @paths.splice @paths.indexOf(path), 1
            delete @files[path]
        null


    compile: (files) ->
        for file in files
            path = file.path
            if not file.removed
                @addPath path # updates version, if already added
            else
                @removePath path

        if not @initialized
            @errors = @compileAll @paths, options
        else
            @createService() if not @service
            @errors = []
            for file in files
                @compilePath file.path if not file.removed

            program        = @service.getProgram()
            emitResult     = program.emit()
            allDiagnostics = ts.getPreEmitDiagnostics(program).concat emitResult.diagnostics
            allDiagnostics.forEach (diagnostic) =>
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                message             = ts.flattenDiagnosticMessageText diagnostic.messageText, '\n'
                @errors.push "  Error #{diagnostic.file.fileName} (#{line + 1}, #{character + 1}): #{message}"

        @compiled()
        null


    compileAll: (paths, options) ->
        program    = ts.createProgram paths, options #@service.getProgram()
        emitResult = program.emit()

        allDiagnostics = ts.getPreEmitDiagnostics(program).concat emitResult.diagnostics

        errors = []
        allDiagnostics.forEach (diagnostic) ->
            { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
            message             = ts.flattenDiagnosticMessageText diagnostic.messageText, '\n'
            errors.push "  Error #{diagnostic.file.fileName} (#{line + 1}, #{character + 1}): #{message}"
        errors


    compilePath: (path) ->
        return null if /.d.ts/.test path

        output  = @service.getEmitOutput path
        #errors  = @getErrors path
        #@errors = @errors.concat errors if errors

        #console.log "Emitting #{path}: "

        for file in output.outputFiles
            FS.writeFileSync file.name, file.text, "utf8"
        null


    getErrors: (path) ->
        allDiagnostics = @service.getCompilerOptionsDiagnostics()
            .concat @service.getSyntacticDiagnostics(path)
            .concat @service.getSemanticDiagnostics(path)

        errors = []
        allDiagnostics.forEach (diagnostic) ->
            message = ts.flattenDiagnosticMessageText diagnostic.messageText, '\n'
            if diagnostic.file
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                errors.push "  Error #{diagnostic.file.fileName} (#{line + 1}, #{character + 1}):  \r\n#{message}"
            else
                errors.push "  Error: #{message}"

        #console.log 'logErrors: ', path
        errors


    createService: () ->
        @servicesHost =
            getScriptFileNames:    ()     => @paths
            getScriptVersion:      (path) => @files[path] && @files[path].version.toString()
            getScriptSnapshot:     (path) ->
                return undefined if not FSU.isFile path
                ts.ScriptSnapshot.fromString FS.readFileSync(path).toString()
            getCurrentDirectory:    ()        -> process.cwd()
            getCompilationSettings: ()        -> options
            getDefaultLibFileName:  (options) -> ts.getDefaultLibFilePath options

        @service = ts.createLanguageService @servicesHost, ts.createDocumentRegistry()

        #console.log 'service: ', @service

        null


    compiled: () ->
        #console.log 'ts.compiled!!!'
        @initialized = true
        @ipc.send 'compiled', 'ts', @errors




module.exports = new TSCompiler()