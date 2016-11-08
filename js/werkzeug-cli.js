// Generated by CoffeeScript 1.10.0
(function() {
  var WZ, args, build, compile, pack, pkg, watch, wz;

  WZ = require('./werkzeug');

  pkg = require(__dirname + "/../package");

  args = require('karg')("wz\n    arguments  . ? see arguments                   . ** .\n    watch      . ? watch project                   . = false\n    compile    . ? compile project                 . = false\n    pack       . ? create packages                 . = false\n    server     . ? start a server                  . = false\n    verbose    . ? log more                        . = false\n    quiet      . ? log nothing                     . = false\n    debug      . ? log debug                       . = false\narguments\n    [no option]  project path               " + '.'.blue + "\n    watch        project to watch           " + '.'.blue + "\n    compile      project to compile         " + '.'.blue + "\n    pack         project to pack            " + '.'.blue + "\n    build        project to build           " + '.'.blue + "\n    server       project to serve           " + '.'.blue + "\nversion  " + pkg.version);

  wz = new WZ(args["arguments"][0] || process.cwd());

  watch = args.watch;

  build = args.build;

  pack = args.pack || watch || build;

  compile = args.compile || watch || pack;

  watch = !compile || watch;

  if (watch) {
    wz.watch();
  } else {
    wz.walk();
  }

}).call(this);

//# sourceMappingURL=werkzeug-cli.js.map
