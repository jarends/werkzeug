SW     = require './stopwatch'
Colors = require 'colors'
__log  = console.log



Log = (args...) ->
    Log.clearTicker()
    Log.log.apply Log.console, args


Log.console          = console
Log.log              = __log
Log.tickerStarted    = false
Log.tickerText       = ''
Log.tickerTextLength = ''
Log.tickerTimeout    = null
Log.typeLength       = 10
Log.empty            = new Array(81).join(' ')
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


Log.getEmpty = (length) ->
    l = Log.empty.length
    if l < length
        Log.empty += new Array(length - l + 1).join(' ')
    Log.empty.substring 0, length




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
        process.stdout.write '\r' + Log.getEmpty(Log.tickerTextLength) + '\r'
    null


Log.tick = () ->
    clearTimeout Log.tickerTimeout
    if Log.tickerStarted
        text                 = (Log.tickerText + " ... #{Log.ftime('Log.ticker')}").cyan
        oldLength            = Log.tickerTextLength
        newLength            = text.length
        dif                  = oldLength - newLength
        empty                = if dif > 0 then Log.getEmpty(dif) else ''
        Log.tickerTextLength = newLength
        process.stdout.write '\r' + text + empty
        Log.tickerTimeout = setTimeout Log.tick, 100
    null




Log.info = (type, text, time, numErrors, asWarning) ->
    empty = Log.getEmpty(Log.typeLength - type.length)
    text  = text or ''
    info  = type.cyan + empty + '→ '.cyan + text.white
    info += ' in ' + Log.ftime(time) if not isNaN time
    if not isNaN numErrors
        if numErrors > 0
            if not asWarning
                info += ' with ' + "#{numErrors} #{Log.count numErrors, 'error'}".red
            else
                info += ' with ' + "#{numErrors} #{Log.count numErrors, 'warning'}".yellow
        else
            info += ' ' + Log.ok
    Log info
    null




module.exports = Log




