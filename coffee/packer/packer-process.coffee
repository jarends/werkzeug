FS                 = require 'fs'
FSE                = require 'fs-extra'
Path               = require 'path'
nga                = require 'ng-annotate/ng-annotate-main'
Dict               = require 'jsdictionary'
Babel              = require 'babel-core'
Babel_es2015       = require 'babel-preset-es2015'
JMin               = require 'jsonminify'
FSU                = require '../utils/fsu'
PH                 = require '../utils/path-helper'
IPC                = require '../utils/ipc'
Log                = require '../utils/log'
PROCESS_BASE       = Path.join __dirname, '..', '..'
PACK_CODE          = FS.readFileSync Path.join(__dirname, 'pack.js'),  'utf8'
CHUNK_CODE         = FS.readFileSync Path.join(__dirname, 'chunk.js'), 'utf8'
MULTI_COMMENT_MAP  = /\/\*\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)\s*\*\//g
SINGLE_COMMENT_MAP = /\/\/\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)($|\n|\r\n?)/g
ENV                = 'development'

#TODO: make chunk loader mechanism more dynamic (currently only Promis variant available)


getPackCode = (p) -> """
(function(pack)
{
    var win = window,
        process = win.process || (win.process = {})
        env     = process.env || (process.env = {})
        cfg     = {
        index:      #{p.index},
        total:      #{p.total},
        startIndex: #{p.file.index},
        type:       'register::#{p.id}',
        path:       '#{p.file.path}',
        pack:       pack
    };
    env.NODE_ENV = env.NODE_ENV || '#{p.env}'
    var packer = #{if p.index == 0 then PACK_CODE else CHUNK_CODE}
    packer.init(cfg);
})({
#{p.code}
});"""


getChunkCode = (p) -> """
(function(pack)
{
    var cfg = {
        type:       'register::#{p.id}',
        path:       '#{p.file.path}',
        chunk:      '#{p.chunk}',
        pack:       pack
    };
    var chunk = #{CHUNK_CODE}
    chunk.init(cfg);
})({
#{p.code}
});"""


class Indexer

    constructor: () ->
        @current = -1
        @cache   = {}

    get: (path) ->
        cached = @cache[path]
        if not isNaN cached
            return cached
        ++@current

    remove: (path, index) ->
        @cache[path] = index
        null




babelOptions =
    ast:     false
    compact: false
    presets: [Babel_es2015]




class Packer


    constructor: () ->
        @create()


    create: () ->
        @indexer    = new Indexer()
        @fileMap    = {}    # indexing: files mapped by path in tmp or node_modules
        @nodes      = {}    # indexing: currently unused
        @loaders    = {}    # indexing: map of all parsed loaders by path
        @openFiles  = 0     # indexing: number of currently reading files
        @openPacks  = 0     # packaging: number of currently writing packages
        @packed     = null  # packaging: map of already packed files
        @loaded     = null  # packaging: map of chunks loaded by a loader
        @packs      = null  # packaging: list of current packs
        @chunks     = null  # packaging: list of current chunks
        @ipc        = new IPC(process, @)
        @errors     = []
        null


    init: (@cfg) ->
        @id        = Math.random() + '_' + Date.now()
        @nga       = @cfg.packer.nga or false
        @useBabel  = not @cfg.packer.disableBabelFallback
        @useUglify = @cfg.packer.uglify == true
        @env       = @cfg.packer.env or {}
        @NODE_ENV  = @env.NODE_ENV   or 'development'
        @out       = PH.getOut @cfg, 'packer'
        null


    readPackages: () ->
        @errors  = []
        packages = @cfg.packer.packages or []
        for cfg in packages
            path = Path.join @out, cfg.in
            @readFile path
        null


    update: (files) ->
        try
            errors  = @errors
            @errors = []
            updated = {}
            for f in files
                path = PH.outFromIn @cfg, null, f.path, true
                file = @fileMap[path]
                #console.log 'update file: ', path, f.path
                continue if not file or updated[path]
                updated[path] = true
                @clear file
                if not f.removed
                    @readFile path

            for error in errors
                path = error.path
                file = @fileMap[path]
                continue if not file or updated[path]
                updated[path] = true
                @clear file
                @readFile path

            if @openFiles == 0
                @completed()
        catch e
            console.log 'packer error: ', e.toString()
        null




    clear: (file) ->
        path = file.path
        for reqPath of file.req
            req = @fileMap[reqPath]
            delete req.ref[path] if req
            delete file.req[reqPath]

        for loderPath of file.reqAsL
            loaderRefs = @loaders[loderPath]
            if loaderRefs
                delete loaderRefs[path]
                if not Dict.hasKeys loaderRefs
                    delete @loaders[loderPath]
            delete file.reqAsL[loderPath]

        delete @fileMap[path]
        @indexer.remove path, file.index
        null


    isRequired: (file) ->
        Dict.hasKeys file.ref or @loaders[file.path]




    removeSources: (path) ->
        FS.unlinkSync path
        FS.unlinkSync path + '.map'


    writePackages: () ->
        # remove current packs and chunks
        @removeSources(pack.out)  for pack  in @packs  if @packs
        @removeSources(chunk.out) for chunk in @chunks if @chunks


        @totalModules = 0
        @packed       = {}
        @loaded       = {}
        @packs        = []
        @chunks       = []
        packages      = @cfg.packer.packages or []

        # clear loader data
        for path of @fileMap
            file = @fileMap[path]
            file.loaders = {}
            file.parts   = {}

        # create packs and gather all requireds
        for pack, i in packages by -1
            path = Path.join @out, pack.in
            file = @fileMap[path]

            p =
                file:       file
                index:      i
                total:      packages.length
                id:         @id
                out:        Path.join @out, pack.out
                req:        {}
                loaders:    {}
                code:       ''
                env:        @NODE_ENV
                numModules: 0

            @packs.push p
            @gatherReq p, file

        # gather all modules for each loader
        for path of @loaders
            loader = @fileMap[path]
            @gatherChunks loader, loader

        # cleanup modules required by each loader
        for path of @loaded
            @cleanupChunks @fileMap[path]

        for p in @packs
            @writePack p

        for path of @loaders
            loader = @fileMap[path]
            chunk  = @getChunkPath loader
            p =
                file:       loader
                index:      loader.index
                id:         @id
                out:        Path.join @out, chunk
                chunk:      chunk
                code:       ''
                numModules: 0

            @chunks.push p
            @writeChunk p

        null


    getChunkPath: (loader) ->
        @cfg.packer.chunks + loader.index + '.js'


    gatherReq: (p, file) ->
        if @packed[file.index]
            return null
        @packed[file.index] = true
        p.req[file.path]    = true
        for rpath of file.req
            rfile = @fileMap[rpath]
            if not rfile
                @errors.push
                    path:  file.path
                    line:  -1
                    col:   -1
                    error: 'required file not found: ' + rpath
            else if not @packed[rfile.index]
                # add all loaders to the pack -> used by cleanupChunks
                for lpath of rfile.reqAsL
                    p.loaders[lpath] = true
                @gatherReq(p, rfile)
        null


    gatherChunks: (loader, file) ->
        file.loaders[loader.path] = true
        loader.parts[file.path]   = true
        @loaded[file.path]        = true
        for rpath of file.req
            rfile = @fileMap[rpath]
            if not rfile
                @errors.push
                    path:  file.path
                    line:  -1
                    col:   -1
                    error: 'required file not found: ' + rpath
            else
                @gatherChunks(loader, rfile) if not loader.parts[rpath]
        null


    cleanupChunks: (file) ->
        # returns a loader, if the file is required by exactly one loader
        loader = @getLoader file
        path   = file.path
        packed = @packed[file.index]
        # remove file from loaders, if already packed
        # remove also if required by more than one loader in case bigChunks = false
        if packed or (not @cfg.packer.bigChunks and not loader)
            for lpath of file.loaders
                loader = @fileMap[lpath]
                delete loader.parts[path]
                delete file.loaders[lpath]
                # add file to the first matching pack if not already packed
                if not packed
                    for p in @packs
                        if p.loaders[lpath]
                            p.req[path]         = true
                            @packed[file.index] = true
                            packed              = true
                            break
        null


    getLoader: (file) ->
        count = 0
        for path of file.loaders
            ++count
            return null if count > 1
        @fileMap[path]




    initSourceMapping: (pack, type) ->
        if type == 'pack'
            if pack.index == 0
                @lineOffset = 194 + 4
            else
                @lineOffset = 50
        else
            @lineOffset = 48

        origin     = Path.relative @out, pack.out
        @sourceMap =
            version : 3
            file:     origin
            sourceRoot: ''
            sources: [
                origin
            ]
            sections: []
        null


    addSourceMap: (pack, file, singleLine) ->
        @lineOffset += if singleLine then 2 else 3

        map = file.sourceMap
        if map
            @sourceMap.sections.push
                offset:
                    line:   @lineOffset
                    column: 0
                map: map

        @lineOffset += 1 + (if singleLine then 1 else file.numLines)
        null


    writeSourceMap: (pack) ->
        mapOut = pack.out + '.map'
        FSE.ensureFileSync mapOut
        FS.writeFileSync mapOut, JSON.stringify(@sourceMap), 'utf8'
        pack.code += "\r\n//# sourceMappingURL=#{Path.relative @out, pack.out}.map"




    writePack: (p) ->
        @initSourceMapping(p, 'pack')
        @addPackSrc p, @fileMap[path] for path of p.req
        p.code = p.code.slice 0, -3
        p.code = getPackCode p
        ++@openPacks
        @writeSourceMap p

        #TODO: handle write errors
        FSE.ensureFileSync p.out
        FS.writeFile p.out, p.code, 'utf8', (error) =>
            --@openPacks
            if error
                console.log 'packer.writePack: pack write error: ', p.out
            if @openPacks == 0
                @completed()
            null
        null


    writeChunk: (p) ->
        @initSourceMapping(p, 'chunk')
        @addPackSrc p, @fileMap[path] for path of p.file.parts
        p.code = p.code.slice 0, -3
        p.code = getChunkCode p
        ++@openPacks
        @writeSourceMap p

        #TODO: handle write errors
        FSE.ensureFileSync p.out
        FS.writeFile p.out, p.code, 'utf8', (error) =>
            --@openPacks
            if error
                console.log 'packer.writeChunk: chunk write error: ', p.out
            if @openPacks == 0
                @completed()
            null
        null


    addPackSrc: (p, file) ->
        ++@totalModules
        ++p.numModules
        source   = file.source
        source   = nga(source, add:true).src if @nga
        moduleId = Path.relative @out, file.path

        code = "// #{file.path}\r\n#{file.index}: "
        if /.js$/.test file.path
            code += "function(module, exports, require) {\r\nmodule.id = '#{moduleId}';\r\n#{source}\r\n},\r\n"
            @addSourceMap p, file, false

        else
            # replace ' with \'
            source = source.replace /'/g, (args...) ->
                if args[2][args[1] - 1] != '\\' then "\\'" else "'"

            #TODO: check, if this causes problems with JMin
            # surround with quotes
            source = "'#{source}'"

            #TODO: maybe do JSON.parse to check for json -> currently json files without extension can't be required
            if /.json$/.test file.path
                source = "JSON.parse(#{JMin source})"
            # replace newlines with \n
            source = source.replace /\r\n|\n/g, '\\n'

            # html can have nested requireds: ${require('path/to/html')}
            if /.html$/.test file.path
                source = source.replace /\${\s*(require\s*\(\s*\d*?\s*\))\s*}/g, "' + $1 + '"
            code += "function(module, exports, require) {\r\nmodule.exports = #{source};\r\n},\r\n"
            @addSourceMap p, file, true

        p.code += code
        null








    readFile: (path, parent) ->
        file = @fileMap[path]
        if file
            if parent
                parent.req[path]      = true
                file.ref[parent.path] = true
            return file

        file = @fileMap[path] =
            index:     @indexer.get path
            path:      path
            source:    ''
            sourceMap: ''
            numLines:  0
            ref:       {}
            req:       {}
            reqAsL:    {}
            error:     false

        if parent
            parent.req[path]      = true
            file.ref[parent.path] = true

        #console.log 'read file: ', path

        ++@openFiles
        FS.readFile path, 'utf8', (error, source) =>
            if error
                file.error = error
                @errors.push
                    path:  path
                    line:  -1
                    col:   -1
                    error: 'file read error'
            else

                if /\.js$/.test path
                    # uglify
                    if @cfg.packer.uglify
                        source  = source.replace /process\.env\.NODE_ENV/g, 'NODE_ENV'
                        @uglify = @uglify or require 'uglify-js'
                        try
                            result  = @uglify.minify source,
                                fromString: true
                                compress:
                                    global_defs:
                                        'NODE_ENV': @cfg.packer.env?.NODE_ENV or ENV
                        catch e
                            console.log 'error while uglifying: ', path, e

                        source = result.code if result


                    #TODO: babel should be a compiler
                    # use babel if file is in node-modules and isn't an umd module and has an import statement
                    if @useBabel and /node_modules/.test(path) and not /\.umd\./.test(path) and /((^| )import )|((^| )class )|((^| )let )|((^| )const |((^| )export ))/gm.test(source)
                        result = Babel.transform source, babelOptions
                        source = result.code
                        console.log 'babel:       transformed -> ' + Path.relative @cfg.base, path


                # handle source map
                if PH.testJS(path)

                    moduleId   = Path.relative @out, path
                    mapPath    = path + '.map'
                    source     = source.replace SINGLE_COMMENT_MAP, ''
                    source     = source.replace MULTI_COMMENT_MAP,  ''
                    numLines   = (source or '').split(/\r\n|\n/).length
                    fixFF      = @cfg.options.fffMaps
                    includeExt = @cfg.options.includeExternalMaps

                    if FSU.isFile(mapPath) and (path.indexOf(@out) == 0 or includeExt)
                        map            = FSU.require mapPath
                        map.file       = Path.basename path
                        file.sourceMap = map

                        # only touch sourcesContent to fix firefox sourcemap bug
                        if fixFF
                            map.sourcesContent = map.sourcesContent or []

                        # correct paths to original sources
                        # and include sources, if firefox fixing is enabled
                        for sourcePath, i in map.sources
                            absSourcePath = Path.join map.sourceRoot, sourcePath
                            if fixFF and not map.sourcesContent[i]
                                # add all original sources to the map to fix firefox sourcemap bug
                                if FSU.isFile(absSourcePath)
                                    map.sourcesContent.push FS.readFileSync(absSourcePath, 'utf8')
                                else
                                    map.sourcesContent.push ''
                            #console.log '', absSourcePath
                            map.sources[i] = Path.relative @out, absSourcePath

                        map.sourceRoot = ''

                file.moduleId = moduleId
                file.source   = source
                file.numLines = numLines
                @parseFile file

            @writePackages() if --@openFiles == 0
            null
        file




    parseFile: (file) ->
        path   = file.path
        base   = Path.dirname path
        #regex  = /^([^\/]|(\/(?!\/)))*?require\s*\(\s*('|")(.*?)('|")\s*\)/gm
        regex  = /require\s*\(\s*('|")(.*?)('|")\s*\)/gm
        regPos = 2
        loaderRegex = new RegExp('^' + @cfg.packer.loaderPrefix)

        #while result = regex.exec file.source
        file.source = file.source.replace regex, (args...) =>
            name     = PH.correctOut args[regPos]
            isLoader = loaderRegex.test name
            name     = name.replace /^es6-promise\!/, '' if isLoader

            if /\.|\//.test(name[0])
                modulePath = @getRelModulePath base, name
            else
                modulePath = @getNodeModulePath base, name
                if modulePath and not @nodes[modulePath]
                    @nodes[modulePath] = true  # currently unused

            if modulePath
                rfile = @readFile modulePath, file
                if isLoader
                    rpath      = rfile.path
                    loaderRefs = @loaders[rpath] or @loaders[rpath] = {}
                    loaderRefs[path]   = true
                    file.reqAsL[rpath] = true
                    # remove linking to enable chunks
                    delete file.req[rpath]
                    delete rfile.ref[path]

                    return "require(#{rfile.index}, '#{@getChunkPath rfile}')"
                return "require(#{rfile.index})"
            else
                if not @isComment file.source, args[4]
                    @errors.push
                        path:  path
                        line:  -1
                        col:   -1
                        error: 'packer.parseFile: module "' + name + '" not found'

            args[0]
        null


    isComment: (text, index) ->
        sameLine      = true
        behindComment = false
        while --index > -1
            char1         = text[index]
            char2         = text[index + 1]
            chars         = char1 + char2
            sameLine      = sameLine and char1 != '\n'
            insideComment = chars == '/*'
            behindComment = chars == '*/'
            return true  if sameLine and chars == '//'
            return true  if insideComment
            return false if behindComment
        return false





    getRelModulePath: (base, moduleName) ->
        ext  = @testExt moduleName, '.js'
        path = Path.resolve base, moduleName
        return file if @isFile file = path + ext                                  # js file found
        return file if @isFile file = Path.join path, 'index.js'                  # index.js file found
        return path if ext and @isFile path                                       # asset file found
        null


    getNodeModulePath: (base, moduleName) ->
        nodePath   = Path.join base, 'node_modules'
        modulePath = Path.join nodePath, moduleName

        if @isDir nodePath
            ext = @testExt moduleName, '.js'
            return file if @isFile file = modulePath + ext                        # .js
            file = Path.join modulePath, 'package.json'                           # package.json
            try
                json = FSU.requireJson file
                main = json?.main
            catch
            if main
                ext = @testExt main, '.js'
                if @isFile file = Path.join modulePath, main + ext                # main
                    return file
            return file if @isFile file = Path.join modulePath, 'index.js'        # index.js
        if base != @cfg.base and base != PROCESS_BASE and base != '/'             # abort, if outside project root
            return @getNodeModulePath Path.resolve(base, '..'), moduleName        # try next dir

        # try modules shipped with werkzeug
        if base != PROCESS_BASE
            return @getNodeModulePath PROCESS_BASE, moduleName
        null


    testExt: (name, ext) ->
        return '' if new RegExp(ext + '$').test name
        ext


    isDir: (path) ->
        stat = @getStat(path)
        return true if stat?.isDirectory()
        false


    isFile: (path) ->
        stat = @getStat path
        return true if stat?.isFile()
        false


    getStat: (path) ->
        try
            return FS.statSync path
        catch error
            null




    completed: () =>
        info =
            errors:       @errors
            totalModules: @totalModules
            modules:      []
            chunks:       []

        for pack, i in @packs by -1
            info.modules.push
                modules: pack.numModules
                path:    pack.file.path
                out:     pack.out

        for chunk, i in @chunks
            info.chunks.push
                modules: chunk.index
                path:    chunk.file.path
                out:     pack.out

        @ipc.send 'packed', info
        null




    exit: () ->
        null


module.exports = new Packer()
