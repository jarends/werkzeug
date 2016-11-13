FS           = require 'fs'
Path         = require 'path'
nga          = require 'ng-annotate/ng-annotate-main'
Dict         = require 'jsdictionary'
Babel        = require 'babel-core'
Babel_es2015 = require 'babel-preset-es2015'
IPC          = require '../utils/ipc'
PH           = require '../utils/path-helper'


PACK_CODE   = FS.readFileSync Path.join(__dirname, 'pack.js'),  'utf8'
CHUNK_CODE  = FS.readFileSync Path.join(__dirname, 'chunk.js'), 'utf8'


getPackCode = (p) -> """
var ENV = '';
var HMR = false;
(function(pack)
{
    var cfg = {
        index:      #{p.index},
        total:      #{p.total},
        startIndex: #{p.file.index},
        type:       'register::#{p.id}',
        path:       '#{p.file.path}',
        pack:       pack
    };
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
        @free    = []

    get: () ->
        if @free.length
            return @free.shift()
        ++@current

    remove: (index) ->
        @free.unshift index
        null




babelOptions =
    ast:     false
    compact: false
    presets: [Babel_es2015]




class Packer


    constructor: () ->
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


    init: (@cfg) ->
        @id  = Math.random() + '_' + Date.now()
        @nga = @cfg.packer.nga or false
        null


    readPackages: () ->
        @errors  = []
        packages = @cfg.packer?.packages or []
        out      = PH.getOut @cfg, 'packer'
        for cfg in packages
            path = Path.join out, cfg.in
            @readFile path
        null


    update: (files) ->
        errors   = @errors or []
        @errors  = []
        for f in files
            path = PH.outFromIn @cfg, 'packer', f.path, true
            file = @fileMap[path]
            if file
                if file.removed
                    @remove file
                else
                    # indexers unshift/shift behaviour keeps parent linking correct
                    @clear file
                    @readFile path

        for error in errors
            path = error.path
            file = @fileMap[path]
            if file
                # indexers unshift/shift behaviour keeps parent linking correct
                @clear file
                @readFile path

        if @openFiles == 0
            @completed()
        null



    remove: (file) ->
        @clear file

        path = file.path
        for ppath in file.ref
            parent = @fileMap[ppath]
            delete parent.req[path]
            delete file.ref[ppath]
        null


    clear: (file) ->
        path = file.path
        for rpath of file.req
            rfile = @fileMap[rpath]
            delete rfile.ref[path]
            delete file.req[rpath]

        for rpath of file.reqAsL
            loaderRefs = @loaders[rpath]
            if loaderRefs
                delete loaderRefs[path]
                if not Dict.hasKeys loaderRefs
                    delete @loaders[rpath]
            delete file.reqAsL[rpath]

        delete @fileMap[path]
        @indexer.remove file.index
        null




    completed: () =>

        for pack in @packs
            console.log 'pack: ', pack.numModules, pack.file.path

        for chunk in @chunks
            console.log 'chunk: ', chunk.index, chunk.numModules, chunk.file.path

        console.log 'total modules: ', @totalModules
        @ipc.send 'packed', @errors
        null




    writePackages: () ->
        @totalModules = 0
        @packed       = {}
        @loaded       = {}
        @packs        = []
        @chunks       = []
        packages      = @cfg.packer.packages or []
        dest          = PH.getOut @cfg, 'packer'

        #TODO: delete existing pack and chunk files

        for path of @fileMap
            file = @fileMap[path]
            file.loaders = {}
            file.parts   = {}

        for pack, i in packages by -1
            path = Path.join dest, pack.in
            file = @fileMap[path]
            p =
                file:       file
                index:      i
                total:      packages.length
                id:         @id
                out:        Path.join dest, pack.out
                req:        {}
                loaders:    {}
                code:       ''
                numModules: 0

            @packs.push p
            @gatherReq p, file

        for path of @loaders
            loader = @fileMap[path]
            @gatherChunks loader, loader

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
                out:        Path.join dest, chunk
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
            if rfile and not @packed[rfile.index]
                # add all loaders to the pack -> used by cleanupChunks
                for lpath of rfile.reqAsL
                    p.loaders[lpath] = true
                @gatherReq(p, rfile)
        null


    gatherChunks: (loader, file) ->
        file.loaders[loader.path] = true
        loader.parts[file.path]   = true
        @loaded[file.path]        = true
        for path of file.req
            rfile = @fileMap[path]
            @gatherChunks(loader, rfile) if not loader.parts[rfile.path]
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
        return @fileMap[path]


    writePack: (p) ->
        @addPackSrc p, @fileMap[path] for path of p.req
        p.code = p.code.slice 0, -3
        p.code = getPackCode(p)
        ++@openPacks

        #TODO: handle write errors
        FS.writeFile p.out, p.code, 'utf8', (error) =>
            --@openPacks
            if error
                console.log 'packer.writePack: pack write error: ', p.out
            if @openPacks == 0
                @completed()
            null
        null


    writeChunk: (p) ->
        @addPackSrc p, @fileMap[path] for path of p.file.parts
        p.code = p.code.slice 0, -3
        p.code = getChunkCode(p)
        ++@openPacks

        #TODO: handle write errors
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
        source = file.source
        source = nga(source, add:true).src if @nga

        code = "// #{file.path}\r\n#{file.index}: "
        if /.js$/.test file.path
            code += "function(module, exports, require) {\r\n#{source}\r\n},\r\n"
        else
            str = source.replace(/'/g, '\\\'').replace(/\r\n|\n/g, '\\n')
            if /.html$/.test file.path
                str = str.replace /\${\s*(require\s*\(\s*\d*?\s*\))\s*}/g, '\' + $1 + \''
            code += "function(module, exports, require) {\r\nmodule.exports = '#{str}';\r\n},\r\n"

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
            index:   @indexer.get()
            path:    path
            source:  ''
            ref:     {}
            req:     {}
            reqAsL:  {}
            error:   false

        if parent
            parent.req[path]      = true
            file.ref[parent.path] = true

        #console.log 'read file: ', path

        ++@openFiles
        FS.readFile path, 'utf8', (error, source) =>
            if error
                file.error = error
                @errors.push
                    path: path
                    line: 0
                    col:  0
                    text: 'file read error'
            else
                #TODO: think about a better detection
                # use babel if file is in node-modules and isn't an umd module and has an import statement
                if /node_modules/.test(path) and not /\.umd\./.test(path) and /import /g.test(source)
                    result      = Babel.transform source, babelOptions
                    console.log 'babel transformed: ' + path
                    file.source = result.code
                else
                    file.source = source
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
        loaderRegex = new RegExp(@cfg.packer.loaderPrefix)

        #while result = regex.exec file.source
        file.source = file.source.replace(regex, (args...) =>
            name     = PH.correctOut args[regPos]
            isLoader = loaderRegex.test name
            name     = name.replace /^es6-promise\!/, '' if isLoader
            isRel    = /\.|\//.test(name[0])

            if isRel
                pathObj = @getRelModulePath base, name
            else
                pathObj = @getNodeModulePath base, name
                if pathObj and not @nodes[pathObj.path]
                    @nodes[pathObj.path] = true  # currently unused

            if pathObj
                rfile = @readFile pathObj.path, file
                if pathObj.main # currently unused
                    rfile.modulePath = pathObj.modulePath
                    rfile.main       = pathObj.main
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
                @errors.push
                    path: path
                    line: 0
                    col:  0
                    text: 'packer.parseFile: module "' + name + '" not found'

            args[0])
        null



    getRelModulePath: (base, moduleName) ->
        ext  = @getExt moduleName, '.js'
        path = Path.join base, moduleName
        return {path:file} if @isFile file = path + ext                    # js file found
        return {path:file} if @isFile file = Path.join path, 'index.js'    # index.js file found
        return {path:path} if ext and @isFile path                         # asset file found
        null


    getNodeModulePath: (base, moduleName) ->
        nodePath   = Path.join base, '/node_modules'
        modulePath = Path.join nodePath, moduleName

        if @isDir nodePath
            ext = @getExt moduleName, '.js'
            return {path:file} if @isFile file = modulePath + ext                           # .js
            if @isFile file = Path.join modulePath, '/package.json'                         # package.json
                try
                    json = require file
                    main = json?.main
                catch
                if main and @isFile file = Path.join modulePath, main    # main
                    return {path:file, modulePath:modulePath, main:main}
            return {path:file} if @isFile file = Path.join modulePath, 'index.js'           # index.js
        if base != @cfg.base                                                                # abort, if outside project root
            return @getNodeModulePath Path.resolve(base, '..'), moduleName                  # try next dir
        null


    getExt: (name, ext) ->
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


    exit: () ->
        null


module.exports = new Packer()
