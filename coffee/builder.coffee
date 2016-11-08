class Builder

    constructor: (@wz) ->
        @cfg = @wz.cfg


    build: () ->
        console.log 'build'


module.exports = Builder