Path      = require 'path'
Colors    = require 'colors'
stripAnsi = require 'strip-ansi'
SW        = require './stopwatch'
__log     = console.log



Log = (args...) ->
    Log.clearTicker()
    Log.log.apply Log.console, args


Log.console          = console
Log.log              = __log
Log.tickerStarted    = false
Log.tickerText       = ''
Log.tickerTextLength = ''
Log.tickerTimeout    = null
Log.typeLength       = 12
Log.chars            = {}
Log.ok               = '✓'.green


Log.mapLogs = () ->
    console.log = Log
    Log.console = Log
    Log


Log.count = (length, text) ->
    return text + 's' if not length or length > 1
    text


Log.time = (timeOrId) ->
    t = if isNaN(timeOrId) then SW.stop(timeOrId) or 0 else timeOrId
    s = ''
    if t < 1000
        s = t + 'ms'
    else if t < 60000
        s = (t / 1000).toFixed(2) + 's'
    else if t < 1000 * 60 * 60
        s = Math.floor(t / 60000) + 'm' + ((t % 60000) / 1000).toFixed(2) + 's'
    else
        s = t + 'ms'
    return s


Log.ftime = (id) ->
    Log.time(id).black.bgWhite.bold


Log.getChars = (char, length) ->
    chars = Log.chars[char]
    if not chars
        chars = Log.chars[char] = ''
    l = chars.length
    if l < length
        chars += new Array(length - l + 1).join(char)
    chars.substring 0, length


Log.lines = (args...) ->
    Log args.join('\r\n')


Log.prefix = (text) ->
    empty = Log.getChars ' ', Log.typeLength - text.length
    text + empty + '→ '


Log.align = (tabs, text) ->
    empty = Log.getChars ' ', tabs
    text.replace /(\r\n|\n)( )*/g, '\n' + empty





Log.startTicker = (text) ->
    if Log.tickerStarted
        Log.stopTicker()
    Log.tickerStarted = true
    Log.tickerText    = text
    SW.start 'Log.ticker'
    Log.tick()
    null


Log.setTicker = (text) ->
    if Log.tickerStarted
        Log.clearTicker()
        Log.tickerText = text
        Log.tick()
    null


Log.stopTicker = () ->
    if Log.tickerStarted
        Log.tickerStarted = false
        Log.clearTicker()
        clearTimeout Log.tickerTimeout
        return SW.stop 'Log.ticker'
    0


Log.clearTicker = () ->
    if Log.tickerStarted
        process.stdout.write '\r' + Log.getChars(' ', Log.tickerTextLength) + '\r'
    null


Log.tick = () ->
    clearTimeout Log.tickerTimeout
    if Log.tickerStarted
        text                 = (Log.tickerText + " ... #{Log.ftime('Log.ticker')}").cyan
        oldLength            = Log.tickerTextLength
        newLength            = text.length
        dif                  = oldLength - newLength
        empty                = if dif > 0 then Log.getChars(' ', dif) else ''
        Log.tickerTextLength = newLength
        process.stdout.write '\r' + text + empty
        Log.tickerTimeout = setTimeout Log.tick, 100
    null




Log.info = (type, text, time, numErrors, asWarning) ->
    empty = Log.getChars(' ', Log.typeLength - type.length)
    text  = text or ''
    info  = Log.prefix(type).cyan + text.white
    info += ' in ' + Log.ftime(time) if not isNaN time
    if not isNaN numErrors
        if numErrors > 0
            if not asWarning
                info += ' with ' + "#{numErrors} #{Log.count numErrors, 'error'}".red
            else
                info += ' with ' + "#{numErrors} #{Log.count numErrors, 'warning'}".white
        else
            info += ' ' + Log.ok
    Log info
    null




Log.error = (errors, base) ->
    return if not errors or not errors.length
    errors.sort Log.sortByPath
    type    = errors[0].type
    count   = errors.length
    info    = type + ' has ' + count + ' ' + Log.count(count, 'Error')
    oldPath = null
    line    = Log.getChars ' ', info.length
    Log.lines '', info.red, line.bgRed

    for error in errors
        text = error.error
        line = error.line
        col  = error.col
        path = error.path
        path = '.' + path.replace(base, '') if path.indexOf(base) == 0
        t0   = "[#{type}]:  "

        if not isNaN(line) and not isNaN(col)
            t1 = ("[#{line}, #{col}]")
        else if not isNaN(line)
            t1 = ("[line #{col}]")
        else if not isNaN(col)
            t1 = ("[col #{col}]")
        else
            t1 = Log.prefix("[common]")

        l    = Log.typeLength + 2
        t0   = t0 + Log.getChars(' ', l - t0.length) + path
        t1   = t1 + Log.getChars(' ', l - t1.length)
        text = Log.align l, stripAnsi(text)

        if oldPath != path
            Log.lines '', t0.red, t1.red + text.red
        else
            Log t1.red + text.red
        oldPath = path

    null


Log.warn = (errors, base) ->
    return if not errors or not errors.length
    errors.sort Log.sortByPath
    type    = errors[0].type
    count   = errors.length
    info    = type + ' has ' + count + ' ' + Log.count(count, 'Warning')
    oldPath = null
    line    = Log.getChars ' ', info.length
    Log.lines '', info.white, line.bgWhite

    for error in errors
        text = error.warning
        line = error.line
        col  = error.col
        path = error.path
        path = '.' + path.replace(base, '') if path.indexOf(base) == 0
        t0   = "[#{type}]:  "

        if not isNaN(line) and not isNaN(col)
            t1 = ("[#{line}, #{col}]")
        else if not isNaN(line)
            t1 = ("[line #{col}]")
        else if not isNaN(col)
            t1 = ("[col #{col}]")
        else
            t1 = Log.prefix("[common]")

        l    = Log.typeLength + 2
        t0   = t0 + Log.getChars(' ', l - t0.length) + path
        t1   = t1 + Log.getChars(' ', l - t1.length)
        text = Log.align l, stripAnsi(text)
        if oldPath != path
            Log.lines '', t0.white, t1.white + text.white
        else
            Log t1.white + text.white

    null




sortByPath = (e0, e1) ->
    if e0.path < e1.path
        return -1
    else if e0.path > e1.path
        return 1

    l0 = e0.line
    l1 = e1.line
    l0 = -1 if isNaN l0
    l1 = -1 if isNaN l1
    if l0 < l1
        return -1
    else if l0 > l1
        return 1

    c0 = e0.col
    c1 = e1.col
    c0 = -1 if isNaN c0
    c1 = -1 if isNaN c1
    if c0 < c1
        return -1
    else if c0 > c1
        return 1

    return 0




module.exports = Log




