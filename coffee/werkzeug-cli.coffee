WZ   = require './werkzeug'
pkg  = require "#{__dirname}/../package"
args = require('karg') """
wz
    arguments  . ? see arguments                   . ** .
    watch      . ? watch project                   . = false
    compile    . ? compile project                 . = false
    pack       . ? create packages                 . = false
    server     . ? start a server                  . = false
    verbose    . ? log more                        . = false
    quiet      . ? log nothing                     . = false
    debug      . ? log debug                       . = false
arguments
    [no option]  project path               #{'.'.blue}
    watch        project to watch           #{'.'.blue}
    compile      project to compile         #{'.'.blue}
    pack         project to pack            #{'.'.blue}
    build        project to build           #{'.'.blue}
    server       project to serve           #{'.'.blue}
version  #{pkg.version}
"""

#console.log 'args: ', args

wz      = new WZ(args.arguments[0] or process.cwd())
watch   = args.watch
build   = args.build
pack    = args.pack    or watch or build
compile = args.compile or watch or pack
watch   = not compile  or watch

#console.log 'wz.cfg: ', wz.cfg

if watch
    wz.watch()
else
    wz.walk()

