class StopWatch


    @instance = new StopWatch()


    @start: (id) -> @instance.start id
    @stop:  (id) -> @instance.stop  id


    constructor: () ->
        @map = {}


    start: (id) ->
        @map[id] = Date.now()
        null


    stop: (id) ->
        now   = Date.now()
        start = @map[id] or now
        now - start


module.exports = StopWatch
