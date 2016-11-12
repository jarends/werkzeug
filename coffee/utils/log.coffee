SW = require './stopwatch'

module.exports =

    count: (length, text) ->
        text + 's' if not length or length > 1
        text

    time: (id) ->
        t = SW.stop(id) or 0
        t + 'ms' if t < 1000
        (t / 1000).toFixed(2) + 's' if t < 60000
        Math.floor(t / 60000) + 'm' + ((t % 60000) / 1000) + 's' if t < 1000 * 60 * 60
        t + 'ms'


