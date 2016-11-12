Path = require 'path'
FSU  = require './utils/fsu'
Home = require 'homedir'
_    = require './utils/pimped-lodash'


class Config


    constructor: (@base, cfgOrPath) ->
        if _.isString cfgOrPath
            cfg = FSU.require Path.join(@base, cfgOrPath)
            cfg = FSU.require cfgOrPath if not cfg

        cfg = FSU.require @base,  '.werkzeug' if not cfg
        cfg = FSU.require Home(), '.werkzeug' if not cfg
        def = FSU.require __dirname, '..', '.default.werkzeug'

        _.deepMerge @, def, cfg


module.exports = Config