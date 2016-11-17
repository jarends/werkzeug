FS     = require 'fs'
Path   = require 'path'
ts     = require 'typescript'
Linter = require 'tslint'
Walk   = require 'walkdir'
Home   = require 'homedir'
_      = require '../utils/pimped-lodash'
FSU    = require '../utils/fsu'
IPC    = require '../utils/ipc'
SW     = require '../utils/stopwatch'
PH     = require '../utils/path-helper'


#TODO: load project specific tsconfig and put options in .default.tsconfig

node_modules = Path.join __dirname, '..', '..', 'node_modules'

options =
    target:                         ts.ScriptTarget.ES5
    module:                         ts.ModuleKind.CommonJS
    moduleResolution:               ts.ModuleResolutionKind.NodeJs
    rootDir:                        ''
    outDir:                         ''
    baseUrl:                        node_modules
    sourceMap:                      true
    experimentalDecorators:         true
    emitDecoratorMetadata:          true
    removeComments:                 false
    noImplicitAny:                  false
    noEmit:                         false
    noEmitHelpers:                  true
    importHelpers:                  true
    noEmitOnError:                  false
    preserveConstEnums:             true
    suppressImplicitAnyIndexErrors: true
    allowSyntheticDefaultImports:   true


linterOptions =
    formatter:     'json'
    configuration: {}


class TSCompiler


    constructor: () ->
        @initialized   = false
        @cfg           = null
        @tscfg         = null
        @errors        = null
        @linterErrors  = []
        @linterMap     = {}
        @fileMap       = {}
        @paths         = []
        @program       = null
        @sprogram      = null
        @ipc           = new IPC(process, @)


    init: (@cfg) ->
        @tslintCfg      = {}
        @inBase         = PH.getIn  @cfg, 'ts'
        @outBase        = PH.getOut @cfg, 'ts'
        options.rootDir = @inBase
        options.outDir  = @outBase
        options.sourceRoot = ''
        @parseTSConfig()
        @addTypings()
        @loadTSLintConfig()
        null


    parseTSConfig: () ->
        @tscfg = FSU.require @cfg.base, 'tsconfig.json'

        if @tscfg
            parsed = ts.convertCompilerOptionsFromJson @tscfg.compilerOptions
            console.log 'parsed config: ', parsed

        null


    addTypings: () ->
        # add es6 definitions required by angular2
        @addPath Path.join __dirname, '../../node_modules/typescript/lib/lib.es6.d.ts'

        # add all definitions from new @types system
        tpath = Path.join @cfg.base, 'node_modules', '@types'
        if FSU.isDir tpath
            Walk.sync tpath, (path, stat) =>
                @addPath path if stat.isFile() and /\.d\.ts$/.test path
        null


    loadTSLintConfig: () ->
        cfg = FSU.require @cfg.base, 'tslint.json'
        cfg = FSU.require Home(), 'tslint.json' if not cfg
        cfg = FSU.require __dirname, '..', '..', '.default.tslint.json'  if not cfg

        #TODO: handle error
        if not cfg
            console.log 'ERROR: tslint config not found!!'

        _.deepMerge linterOptions.configuration, cfg
        null


    addPath: (path) ->
        #return null if /\.d\.ts/.test path

        file = @fileMap[path]
        if not file
            @paths.push path
            @fileMap[path] = version:0, path:path
        else
            ++file.version
        null


    removePath: (path) ->
        if @fileMap[path]
            @paths.splice @paths.indexOf(path), 1
            delete @fileMap[path]
        delete @linterMap[path]
        null


    compile: (files) ->
        @files = []
        for file in files
            path = file.path
            if not file.removed
                @addPath path # updates version, if already added
                @files.push @fileMap[path]
            else
                @removePath path

        @errors = []
        @createService() if not @service

        if not @initialized or files.length > 20
            @compileAll @paths, options
        else
            @program = @service.getProgram()
            for file in files
                @compilePath(file.path) if not file.removed

        @compiled()
        null


    compileAll: (paths, options) ->
        @program       = ts.createProgram paths, options
        emitResult     = @program.emit()
        allDiagnostics = ts.getPreEmitDiagnostics(@program).concat emitResult.diagnostics

        allDiagnostics.forEach (diagnostic) =>
            if diagnostic.file
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                message             = ts.flattenDiagnosticMessageText diagnostic.messageText, '\n'
                @errors.push
                    path: diagnostic.file.fileName
                    line: line + 1
                    col:  character + 1
                    text: message
            #TODO: handle error somehow
            else
                console.log 'diagnostic without file: ', diagnostic
        null


    compilePath: (path) ->
        return null if /\.d\.ts/.test path

        output         = @service.getEmitOutput path
        allDiagnostics = @service.getSyntacticDiagnostics(path).concat @service.getSemanticDiagnostics(path)
        hasErrors      = false

        allDiagnostics.forEach (diagnostic) =>
            hasErrors           = false
            if diagnostic.file
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                message             = ts.flattenDiagnosticMessageText diagnostic.messageText, '\n'
                @errors.push
                    path: diagnostic.file.fileName
                    line: line + 1
                    col:  character + 1
                    text: message
            #TODO: handle error somehow
            else
                console.log 'diagnostic without file: ', diagnostic

        if not hasErrors or true
            for file in output.outputFiles
                FS.writeFileSync file.name, file.text, "utf8"
        null




    createService: () ->
        @servicesHost =
            getScriptFileNames:    ()     => @paths
            getScriptVersion:      (path) => @fileMap[path] && @fileMap[path].version.toString()
            getScriptSnapshot:     (path) ->
                return undefined if not FSU.isFile path
                ts.ScriptSnapshot.fromString FS.readFileSync(path).toString()
            getCurrentDirectory:    ()        -> process.cwd()
            getCompilationSettings: ()        -> options
            getDefaultLibFileName:  (options) -> ts.getDefaultLibFilePath options

        @service = ts.createLanguageService @servicesHost, ts.createDocumentRegistry()
        null


    lint: () ->
        #remove errors for changed files
        errors = []
        map    = {}

        for file in @files
            map[file.path] = true

        for error in @linterErrors
            errors.push error if not map[error.path]

        @linterErrors = errors

        for file in @files
            path             = file.path
            file             = @program.getSourceFile path
            @linterMap[path] = file.text
            @lintFile path

        null


    lintFile: (path) ->
        linter = new Linter(path, @linterMap[path], linterOptions)
        result = linter.lint()
        for data in result.failures
            pos = data.startPosition.lineAndCharacter
            @linterErrors.push
                path: path
                line: pos.line + 1
                col:  pos.character + 1
                text: data.failure




    compiled: () ->
        SW.start 'linter'
        @lint() if @errors.length == 0 and (@initialized or not @cfg.tslint.ignoreInitial)

        console.log "linter tooks: #{SW.stop 'linter'}ms"

        @initialized = true

        if @errors.length
            console.log 'ts.errors: \n', @errors

        if @linterErrors.length
            console.log 'tslint.errors: \n', @linterErrors

        @ipc.send 'compiled', 'ts', @errors
        null




module.exports = new TSCompiler()