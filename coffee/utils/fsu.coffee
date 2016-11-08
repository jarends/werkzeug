FS   = require 'fs'
Path = require 'path'


requireSave = (name) ->
    path = name if isFile name
    path = name if isFile name + '.js'
    return null if not path
    try
        require path
    catch e
        null


requireJson = (name) ->
    path = name if isFile name
    path = name if isFile name + '.json'
    return null if not path
    try
        JSON.parse FS.readFileSync(path, 'utf8')
    catch e
        null


requireJsOrJson = (names...) ->
    path = Path.join.apply null, names
    r    = requireSave path
    r    = requireJson path if not r
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


getExt = (path, ext) ->
    return null if not path
    if ext
        return '' if new RegExp( '\\.' + ext + '$').test path
        return ext
    return path.split('.').pop() if path.indexOf '.' > -1
    ''


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

module.exports =
    require:     requireJsOrJson
    requireSave: requireSave
    requireJson: requireJson
    rmDir:       rmDir
    getExt:      getExt
    isDir:       isDir
    isFile:      isFile
    getStat:     getStat
