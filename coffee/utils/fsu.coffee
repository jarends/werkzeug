FS   = require 'fs'
Path = require 'path'


requireSave = (path) ->
    p = path if isFile path
    p = path + '.json' if not p and isFile path + '.json'
    return null if not p
    try
        require p
    catch e
        null


requireJson = (path) ->
    p = path if isFile path
    p = path + '.json' if not p and isFile path + '.json'
    return null if not p
    try
        JSON.parse FS.readFileSync(p, 'utf8')
    catch e
        null


requireJsOrJson = (paths...) ->
    path = Path.join.apply null, paths
    r = requireSave path
    r = requireJson path if not r
    r


rmDir = (dir) ->
    list = FS.readdirSync dir
    for name in list
        file = Path.join dir, name
        stat = FS.statSync file
        if name != '.' and name != '..'
            if stat.isDirectory()
                rmDir file
            else
                FS.unlinkSync file
    FS.rmdirSync dir


testExt = (path, ext) ->
    ext = '.' + ext if ext[0] != '.'
    return '' if new RegExp(ext + '$').test path
    ext


isDir = (path) ->
    stat = getStat(path)
    return true if stat?.isDirectory()
    false


isFile = (path) ->
    stat = getStat path
    return true if stat?.isFile()
    false


getStat = (path) ->
    try
        return FS.statSync path
    catch
        null

getModulePath: (base, name) ->
    if /\.|\//.test(name[0])
        getRelModulePath base, name
    else
        getNodeModulePath base, name


getRelModulePath = (base, name) ->
    ext  = testExt name, '.js'
    path = Path.resolve base, name
    return file if isFile file = path + ext                    # js file found
    return file if isFile file = Path.join path, 'index.js'    # index.js file found
    return path if ext and @isFile path                         # asset file found
    null


getNodeModulePath = (base, name) ->
    nodePath   = Path.join base, 'node_modules'
    modulePath = Path.join nodePath, name

    if isDir nodePath
        ext = testExt name, '.js'
        return file if isFile file = modulePath + ext                                  # .js
        file = Path.join modulePath, 'package.json'                          # package.json
        try
            json = FSU.requireJson file
            main = json?.main
        catch
        if main and isFile file = Path.join modulePath, main                       # main
            return file
        return file if isFile file = Path.join modulePath, 'index.js'           # index.js
    if base != PROCESS_BASE and base != '/'                       # abort, if outside project root
        return @getNodeModulePath Path.resolve(base, '..'), name                  # try next dir
    null



module.exports =
    require:     requireJsOrJson
    requireSave: requireSave
    requireJson: requireJson
    rmDir:       rmDir
    testExt:     testExt
    isDir:       isDir
    isFile:      isFile
    getStat:     getStat
