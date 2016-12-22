Path = require 'path'


TYPES =
    scss:   'sass'
    sass:   'sass'
    less:   'less'
    styl:   'styl'
    ts:     'ts'
    coffee: 'coffee'

    
#TODO: generalize types together with compilers


class PathHelper

    @sass   : /\.sass$|\.scss$/
    @less   : /\.less$/
    @styl   : /\.styl$/
    @ts     : /\.ts$/
    @coffee : /\.coffee$/
    @js     : /\.js$/
    @jsMap  : /\.js\.map$/
    @css    : /\.css$/
    @cssMap : /\.css\.map$/


    @testSass   : (path) -> @sass.  test path
    @testLess   : (path) -> @less.  test path
    @testStyl   : (path) -> @styl.  test path
    @testTS     : (path) -> @ts.    test path
    @testCoffee : (path) -> @coffee.test path
    @testJS     : (path) -> @js.    test path
    @testJSMap  : (path) -> @jsMap. test path
    @testCss    : (path) -> @css.   test path
    @testCssMap : (path) -> @cssMap.test path


    @correctOut = (path) ->
        return path.replace(@sass,   '.css') if @testSass  (path)
        return path.replace(@less,   '.css') if @testLess  (path)
        return path.replace(@styl,   '.css') if @testStyl  (path)
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
        result = /\.(\w*)$/.exec(path)
        ext = if result then result[1] else null
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
        outPaths = []
        out      = cfg.out
        if out and out != cfg.in
            outPaths.push Path.join base, out
        for type of cfg
            out = cfg[type]?.out
            if out and out != cfg[type].in
                out = Path.join base, out
                outPaths.push(out) if outPaths.indexOf(out) == -1
        outPaths




module.exports = PathHelper