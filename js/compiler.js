// Generated by CoffeeScript 1.10.0
(function() {
  var ASSET, CP, Compiler, IPC, Path, Reg, SASS, SW, TS;

  Path = require('path');

  CP = require('child_process');

  IPC = require('./utils/ipc');

  Reg = require('./utils/regex');

  SW = require('./utils/stopwatch');

  TS = Path.join(__dirname, 'compiler', 'ts');

  ASSET = Path.join(__dirname, 'compiler', 'assets');

  SASS = Path.join(__dirname, 'compiler', 'sass');

  Compiler = (function() {
    function Compiler(wz) {
      this.wz = wz;
      this.cfg = this.wz.cfg;
      this.ts = {
        ipc: new IPC(CP.fork(TS), this),
        compiled: false
      };
      this.sass = {
        ipc: new IPC(CP.fork(SASS), this),
        compiled: false
      };
      this.assets = {
        ipc: new IPC(CP.fork(ASSET), this),
        compiled: false
      };
      this.ts.ipc.send('init', this.cfg);
      this.sass.ipc.send('init', this.cfg);
      this.assets.ipc.send('init', this.cfg);
    }

    Compiler.prototype.compile = function() {
      var assets, f, file, i, l, len, path, ref, removed, root, sass, ts, used;
      ts = [];
      sass = [];
      assets = [];
      root = Path.join(this.cfg.base, this.cfg.root);
      this.ts.compiled = false;
      this.sass.compiled = false;
      this.assets.compiled = false;
      SW.start('compiler.ts');
      SW.start('compiler.sass');
      SW.start('compiler.assets');
      SW.start('compiler.all');
      this.errors = [];
      this.files = [];
      ref = this.wz.files;
      for (i = 0, len = ref.length; i < len; i++) {
        file = ref[i];
        if (file.dirty || file.errors) {
          path = file.path;
          removed = file.removed;
          used = false;
          f = {
            path: path,
            removed: removed,
            error: false
          };
          if (Reg.testTS(path)) {
            ts.push(f);
            used = true;
          } else if (Reg.testSass(path) && !removed) {
            sass.push(f);
            used = true;
          } else if (path.indexOf(root) === 0 && !removed) {
            assets.push(f);
            used = true;
          }
          if (removed) {
            assets.push(f);
            used = true;
          }
          if (used) {
            this.files.push(f);
          }
        }
      }
      if (assets.length) {
        this.assets.ipc.send('compile', assets);
      } else {
        this.assets.compiled = true;
      }
      if (sass.length) {
        this.sass.ipc.send('compile', sass);
      } else {
        this.sass.compiled = true;
      }
      if (ts.length) {
        this.ts.ipc.send('compile', ts);
      } else {
        this.ts.compiled = true;
      }
      l = this.files.length;
      if (l) {
        console.log(("start compiling... (" + l + " " + (l > 1 ? 'files' : 'file') + ")").cyan);
      } else {
        this.wz.compiled();
      }
      return null;
    };

    Compiler.prototype.compiled = function(comp, errors) {
      var error, file, i, l, len, path, t;
      this[comp].compiled = true;
      for (i = 0, len = errors.length; i < len; i++) {
        error = errors[i];
        this.errors.push(error);
        path = error.path;
        file = this.wz.fileMap[path];
        if (file) {
          file.errors = true;
        } else {

        }
      }
      t = SW.stop('compiler.' + comp);
      l = errors.length;
      if (l > 0) {
        console.log((comp + " compiled in " + t + "ms with " + errors.length + " " + (l > 1 ? 'errors' : 'error')).red);
      } else {
        console.log((comp + " compiled in " + t + "ms without errors").green);
      }
      if (this.ts.compiled && this.sass.compiled && this.assets.compiled) {
        t = SW.stop('compiler.all');
        l = this.errors.length;
        if (this.errors.length > 0) {
          console.log(("all compiled in " + t + "ms with " + l + " " + (l > 1 ? 'errors' : 'error')).red);
        } else {
          console.log(("all compiled in " + t + "ms without errors").green);
        }
        this.wz.compiled();
      }
      return null;
    };

    Compiler.prototype.exit = function() {
      this.ts.ipc.exit();
      this.sass.ipc.exit();
      this.assets.ipc.exit();
      return null;
    };

    return Compiler;

  })();

  module.exports = Compiler;

}).call(this);
