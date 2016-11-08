coffee  = require 'coffee-script'
fs      = require 'fs'
FSU     = require '../utils/fsu'
IPC     = require '../utils/ipc'


options =
    sourceMap: true
    inlineMap: false
    filename:  ''


class CoffeeCompiler

    constructor: () ->
