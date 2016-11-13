// Generated by CoffeeScript 1.10.0
(function() {
  var FS, IPC, PH, Path, Sass, SassCompiler,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Path = require('path');

  FS = require('fs-extra');

  Sass = require('node-sass');

  IPC = require('../utils/ipc');

  PH = require('../utils/path-helper');

  SassCompiler = (function() {
    function SassCompiler() {
      this.onResult = bind(this.onResult, this);
      this.initialized = false;
      this.cfg = null;
      this.errors = null;
      this.openFiles = 0;
      this.ipc = new IPC(process, this);
    }

    SassCompiler.prototype.init = function(cfg) {
      this.cfg = cfg;
      return null;
    };

    SassCompiler.prototype.compile = function(files) {
      var file, i, len, options, path;
      this.errors = [];
      options = {
        outputStyle: 'compressed',
        sourceMap: true
      };
      for (i = 0, len = files.length; i < len; i++) {
        file = files[i];
        path = file.path;
        if (!/^_/.test(Path.basename(path))) {
          ++this.openFiles;
          options.file = path;
          options.outFile = PH.outFromIn(this.cfg, 'sass', path, true);
          Sass.render(options, this.onResult);
        }
      }
      return null;
    };

    SassCompiler.prototype.onResult = function(error, result) {
      var map, out, path;
      --this.openFiles;
      if (error) {
        this.errors.push({
          path: error.file,
          line: error.line,
          col: error.column,
          text: error.message
        });
      } else {
        path = result.stats.entry;
        out = PH.outFromIn(this.cfg, 'sass', path, true);
        map = out + '.map';
        FS.ensureFileSync(out);
        FS.ensureFileSync(map);
        FS.writeFileSync(out, result.css, 'utf8');
        FS.writeFileSync(map, result.map, 'utf8');
      }
      if (this.openFiles === 0) {
        this.compiled();
      }
      return null;
    };

    SassCompiler.prototype.compiled = function() {
      this.initialized = true;
      return this.ipc.send('compiled', 'sass', this.errors);
    };

    return SassCompiler;

  })();

  module.exports = new SassCompiler();

}).call(this);
