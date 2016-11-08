class StopWatch


    constructor: () ->
        @map = {}


    start: (id) ->
        @map[id] = Date.now()
        null


    stop: (id) ->
        now   = Date.now()
        start = @map[id] or now
        now - start


module.exports = new StopWatch()
