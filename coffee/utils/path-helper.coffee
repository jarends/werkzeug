Path = require 'path'


TYPES =
    scss:   'sass'
    sass:   'sass'
    less:   'less'
    stylus: 'stylus'
    ts:     'ts'
    coffee: 'coffee'


class PathHelper

    @sass   : /\.sass$|\.scss$/
    @less   : /\.less$/
    @stylus : /\.stylus$/
    @ts     : /\.ts$/
    @coffee : /\.coffee$/
    @js     : /\.js$/
    @jsMap  : /\.js\.map$/
    @css    : /\.css$/
    @cssMap : /\.css\.map$/


    @testSass   : (path) -> @sass.  test path
    @testLess   : (path) -> @less.  test path
    @testStylus : (path) -> @stylus.test path
    @testTS     : (path) -> @ts.    test path
    @testCoffee : (path) -> @coffee.test path
    @testJS     : (path) -> @js.    test path
    @testJSMap  : (path) -> @jsMap. test path
    @testCss    : (path) -> @css.   test path
    @testCssMap : (path) -> @cssMap.test path


    @correctOut = (path) ->
        return path.replace(@sass,   '.css') if @testSass  (path)
        return path.replace(@less,   '.css') if @testLess  (path)
        return path.replace(@stylus, '.css') if @testStylus(path)
        return path.replace(@ts,     '.js')  if @testTS    (path)
        return path.replace(@coffee, '.js')  if @testCoffee(path)
        path


    @getIn: (cfg, type) ->
        c = cfg[type]
        p = if c and c.in then c.in else cfg.in
        Path.join cfg.base, p


    @getOut: (cfg, type) ->
        c = cfg[type]
        p = if c and c.out then c.out else cfg.out
        Path.join cfg.base, p


    @getType: (path) ->
        ext = /\.(\w*)$/.exec(path)[1]
        console.log 'get type: ', ext
        TYPES[ext] or 'assets'


    @outFromIn: (cfg, type, path, correct) ->
        type    = @getType(path) if not type
        inPath  = @getIn  cfg, type
        outPath = @getOut cfg, type
        rel     = path.replace inPath, outPath
        return rel if not correct
        PathHelper.correctOut rel


    @getPaths: (cfg) ->
        base     = cfg.base
        outPaths = [Path.join base, cfg.out]
        for type of cfg
            out = cfg[type].out
            if out
                out = Path.join base, out
                outPaths.push(out) if outPaths.indexOf(out) == -1
        outPaths




module.exports = PathHelper