# stylus hack to get correct error informations without parsing the message
StylusUtils         = require 'stylus/lib/utils'
formatExceptionHack = StylusUtils.formatException
StylusUtils.formatException = (err, options) ->
    err.filename = options.filename
    err.lineno   = options.lineno
    err.column   = options.column - 1
    err.text     = err.message
    formatExceptionHack err, options

# another stylus hack to get correct error text in some cases
Lexer       = require 'stylus/lib/lexer'
advanceHack = Lexer.prototype.advance
Lexer.prototype.advance = () ->
    try
        advanceHack.call(this)
    catch
        throw new Error('unexpected end or literal expected')