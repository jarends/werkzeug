Path = require 'path'

r =
    sass:   /\.sass$|\.scss$/
    less:   /\.less$/
    ts:     /\.ts$/
    coffee: /\.coffee$/


r.testSass   = (s) -> r.sass.test   s
r.testLess   = (s) -> r.less.test   s
r.testTS     = (s) -> r.ts.test     s
r.testCoffee = (s) -> r.coffee.test s

r.correctOut = (path) ->
    return path.replace(r.sass,   '.css') if r.testSass(path)
    return path.replace(r.less,   '.css') if r.testLess(path)
    return path.replace(r.ts,     '.js')  if r.testTS(path)
    return path.replace(r.coffee, '.js')  if r.testCoffee(path)
    path

r.correctTmp = (path, base, tmp) ->
    Path.join tmp, Path.relative(base, path)

module.exports = r
