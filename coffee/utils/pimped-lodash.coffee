_ = require 'lodash'

deepExtend = (target, source) ->
    for key, value of source
        if _.isObject(value) and not _.isArray(value)
            targetValue = target[key]
            if not _.isObject targetValue
                targetValue = {}
            target[key] = deepExtend targetValue, value
        else
            target[key] = value
    target


deepMerge = (target, sources...) ->
    for source in sources
        deepExtend target, source
    target

_.deepExtend = deepExtend
_.deepMerge  = deepMerge

module.exports = _
