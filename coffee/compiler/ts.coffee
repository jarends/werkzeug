FS     = require 'fs'
Path   = require 'path'
TS     = require 'typescript'
Linter = require 'tslint'
Walk   = require 'walkdir'
Home   = require 'homedir'
_      = require '../utils/pimped-lodash'
FSU    = require '../utils/fsu'
SW     = require '../utils/stopwatch'
PH     = require '../utils/path-helper'
IPC    = require '../utils/ipc'
Log    = require '../utils/log'
NGTool = require './ng-tool'


ES5Libs = ['lib.dom.d.ts', 'lib.es5.d.ts', 'lib.scripthost.d.ts']
ES6Libs = ['lib.dom.d.ts', 'lib.dom.iterable.d.ts', 'lib.es6.d.ts', 'lib.scripthost.d.ts']


linterOptions =
    formatter:     'json'
    configuration: {}




#TODO: check tslint code, if the ts language service or the ts program can be used more effectively




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
        @sources       = {}
        @nodeModules   = {}
        TS.sys.fileExists = @fileExists
        TS.sys.readFile   = @readFile




    init: (@cfg) ->
        return if not @cfg.out
        @tslintCfg = {}
        @inBase    = PH.getIn  @cfg, 'ts'
        @outBase   = PH.getOut @cfg, 'ts'
        @loadTSConfig()
        @loadTSLintConfig()
        @addTypings()
        null


    loadTSConfig: () ->
        @tscfg = FSU.require __dirname, '..', '..', '.default.tsconfig'
        @tscfg = TS.convertCompilerOptionsFromJson @tscfg.compilerOptions

        tscfg = FSU.require @cfg.base, 'tsconfig'
        if tscfg and tscfg.compilerOptions
            tscfg  = TS.convertCompilerOptionsFromJson tscfg.compilerOptions
            @tscfg = _.deepExtend @tscfg, tscfg

        @tscfg.options.sourceMap  = true
        @tscfg.options.rootDir    = @inBase
        @tscfg.options.outDir     = @outBase
        @tscfg.options.sourceRoot = Path.relative @outBase, @inBase
        @tscfg.options.baseUrl    = Path.join __dirname, '..', '..', 'node_modules'
        null


    loadTSLintConfig: () ->
        cfg = FSU.require @cfg.base, 'tslint'
        cfg = FSU.require Home(), 'tslint' if not cfg
        cfg = FSU.require __dirname, '..', '..', '.default.tslint'  if not cfg

        #TODO: handle error
        if not cfg
            console.log 'ERROR: tslint config not found!!'

        _.deepMerge linterOptions.configuration, cfg
        null


    addTypings: () ->
        opt  = @tscfg.options
        libs = opt.lib

        if not libs or libs.length == 0
            target = @tscfg.options.target
            libs   = switch target
                when 1 then ES5Libs
                when 2 then ES6Libs
                else []

        libPath = Path.join __dirname, '../../node_modules/typescript/lib'
        for lib in libs
            path = Path.join libPath, lib
            @addPath(path) if FSU.isFile path

        types     = opt.types or []
        typeRoots = opt.typeRoots or ['node_modules/@types']
        #TODO: use configuration
        for path in typeRoots
            path = Path.resolve @cfg.base, path
            if FSU.isDir path
                Walk.sync path, (typePath, stat) =>
                    if /\.d\.ts$/.test(typePath) and stat.isFile()
                        @addPath(typePath)
        null








    addPath: (path) ->
        file = @fileMap[path]
        if not file
            @paths.push path
            @fileMap[path] = version:0, path:path
        else
            ++file.version

        src = FS.readFileSync path, 'utf8'
        if @cfg.ts.ngTool
            src = NGTool.run path, src, @cfg
        @sources[path] = src
        null




    removePath: (path) ->
        if @fileMap[path]
            @paths.splice @paths.indexOf(path), 1
            delete @fileMap[path]
        delete @linterMap[path]
        delete @sources[path]
        null




    compile: (files) ->
        try
            if not @cfg.out
                @compiled()
                return

            @files = []
            removed = false
            for file in files
                path = file.path
                if not file.removed
                    @addPath path # updates version, if already added
                    @files.push @fileMap[path]
                else
                    removed = true
                    @removePath path

            @errors = []
            @createService() if not @service

            if not @initialized or files.length > 20 or removed
                @compileAll @paths
            else
                @program = @service.getProgram()
                for file in files
                    @compilePath(file.path) if not file.removed

            @compiled()
        catch e
            console.log 'ts error: ', e.toString()
        null




    compileAll: (paths) ->
        @createProgram(paths)

        @program       = @progAll
        emitResult     = @program.emit()
        allDiagnostics = TS.getPreEmitDiagnostics(@program).concat emitResult.diagnostics

        allDiagnostics.forEach (diagnostic) =>
            if diagnostic.file
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                message             = TS.flattenDiagnosticMessageText diagnostic.messageText, '\n'
                @addError
                    path:  diagnostic.file.fileName
                    line:  line + 1
                    col:   character + 1
                    error: message
            #TODO: handle error somehow
            else
                console.log 'diagnostic without file: ', diagnostic
        null




    compilePath: (path) ->
        return null if /\.d\.ts/.test path

        output         = @service.getEmitOutput path
        allDiagnostics = @service.getSyntacticDiagnostics(path).concat @service.getSemanticDiagnostics(path)
        errors         = count:0

        allDiagnostics.forEach (diagnostic) =>
            if diagnostic.file
                ++errors.count
                { line, character } = diagnostic.file.getLineAndCharacterOfPosition diagnostic.start
                message             = TS.flattenDiagnosticMessageText diagnostic.messageText, '\n'
                @addError
                    path:  diagnostic.file.fileName
                    line:  line + 1
                    col:   character + 1
                    error: message
            #TODO: handle error somehow
            else
                console.log 'diagnostic without file: ', diagnostic

        if errors.count == 0
            for file in output.outputFiles
                FS.writeFileSync file.name, file.text, "utf8"
        null




    addError: (error) ->
        for e in @errors
            equal = true
            for key, value of e
                equal = equal and (error[key] == value)
            return if equal
        @errors.push error




    createProgram: (paths) ->
        host = TS.createCompilerHost @tscfg.options
        host.resolveModuleNames = @resolveModuleNames
        @progAll = TS.createProgram paths, @tscfg.options, host
        null




    createService: () ->
        @servicesHost =
            getScriptFileNames: () =>
                @paths

            getScriptVersion: (path) =>
                @fileMap[path] and @fileMap[path].version.toString()

            getScriptSnapshot: (path) =>
                try
                    TS.ScriptSnapshot.fromString @readFile(path)
                catch
                    undefined

            getCurrentDirectory: () =>
                @cfg.base

            getCompilationSettings: () =>
                @tscfg.options

            getDefaultLibFileName: (options) ->
                @defaultLibFilePath or @defaultLibFilePath = TS.getDefaultLibFilePath options

            resolveModuleNames: @resolveModuleNames


        @service = TS.createLanguageService @servicesHost, TS.createDocumentRegistry()
        null




    fileExists: (path) =>
        ###
        name = null
        if /node_modules/.test path
            last       = path.lastIndexOf 'node_modules'
            name       = path.substr last + 13
            modulePath = @nodeModules[name]
            src        = @sources[modulePath]

            if src and /@angular\/core\/index.d.ts$/.test path
                console.log 'found mapped node module: ', name, path

            if src
                return modulePath == path

        if name and /@angular\/core\/index.d.ts$/.test path
            console.log 'initial map node module: ', name, path

        @nodeModules[name] = path if name
        ###
        FSU.isFile path




    readFile: (path) =>
        src = @sources[path]
        return src if src
        @sources[path] = FS.readFileSync path, 'utf8'




    resolveModuleNames: (moduleNames, containingFile) =>

        #TODO: try to hack ts module development problem here

        map = []
        opt = @tscfg.options
        api = {fileExists:@fileExists, readFile:@readFile}
        for moduleName in moduleNames
            result = TS.resolveModuleName moduleName, containingFile, opt, api

            if result.resolvedModule
                map.push result.resolvedModule
            else if moduleName == 'tslib'
                console.log 'resolve tslib: ', Path.resolve('../../node_modules/tslib')
                map.push Path.resolve('../../node_modules/tslib')
            else
                map.push undefined
        map




    lint: () ->
        #remove errors for changed files
        errors = []
        fmap   = {}
        emap   = {}

        for file in @files
            fmap[file.path] = true

        for error in @errors
            emap[error.path] = true

        for error in @linterErrors
            errors.push error if not fmap[error.path] and not emap[error.path]

        @linterErrors = errors

        for file in @files
            path = file.path
            if not emap[path]
                file             = @program.getSourceFile path
                @linterMap[path] = file.text
                @lintFile path
        null




    lintFile: (path) ->
        linter = new Linter(path, @linterMap[path], linterOptions, @program)
        result = linter.lint()
        for data in result.failures
            pos = data.startPosition.lineAndCharacter
            @linterErrors.push
                path:    path
                line:    pos.line + 1
                col:     pos.character + 1
                warning: data.failure
                type:    'tslint'
        null




    compiled: () ->
        if (@initialized or not @cfg.tslint.ignoreInitial)
            SW.start 'linter'
            @lint()
            Log.info 'tslint', 'ready', SW.stop('linter'), @linterErrors.length, true

        @initialized = true
        @ipc.send 'compiled', 'ts', @errors.concat(@linterErrors)
        null




module.exports = new TSCompiler()