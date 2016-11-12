// Generated by CoffeeScript 1.10.0
(function() {
  var FS, FSU, Home, IPC, Linter, Path, SW, TSCompiler, Walk, _, linterOptions, options, ts;

  FS = require('fs-extra');

  Path = require('path');

  ts = require('typescript');

  Linter = require('tslint');

  Walk = require('walkdir');

  Home = require('homedir');

  _ = require('../utils/pimped-lodash');

  FSU = require('../utils/fsu');

  IPC = require('../utils/ipc');

  SW = require('../utils/stopwatch');

  options = {
    declaration: false,
    target: ts.ScriptTarget.ES5,
    module: ts.ModuleKind.CommonJS,
    moduleResolution: ts.ModuleResolutionKind.NodeJs,
    rootDir: '',
    outDir: '',
    sourceMap: true,
    emitBOM: false,
    experimentalDecorators: true,
    emitDecoratorMetadata: true,
    allowSyntheticDefaultImports: true,
    removeComments: false,
    noImplicitAny: false,
    noEmit: false,
    noEmitHelpers: true,
    noEmitOnError: false,
    preserveConstEnums: true,
    suppressImplicitAnyIndexErrors: true
  };

  linterOptions = {
    formatter: 'json',
    configuration: {}
  };

  TSCompiler = (function() {
    function TSCompiler() {
      this.initialized = false;
      this.cfg = null;
      this.errors = null;
      this.linterErrors = [];
      this.linterMap = {};
      this.fileMap = {};
      this.paths = [];
      this.program = null;
      this.sprogram = null;
      this.ipc = new IPC(process, this);
    }

    TSCompiler.prototype.init = function(cfg1) {
      this.cfg = cfg1;
      options.outDir = Path.join(this.cfg.base, this.cfg.tmp);
      options.rootDir = this.cfg.base;
      this.tslintCfg = {};
      this.addTypings();
      this.loadTSLintConfig();
      return null;
    };

    TSCompiler.prototype.addTypings = function() {
      var tpath;
      this.addPath(Path.join(__dirname, '../../node_modules/typescript/lib/lib.es6.d.ts'));
      tpath = Path.join(this.cfg.base, 'node_modules', '@types');
      if (FSU.isDir(tpath)) {
        Walk.sync(tpath, (function(_this) {
          return function(path, stat) {
            if (stat.isFile() && /\.d\.ts$/.test(path)) {
              return _this.addPath(path);
            }
          };
        })(this));
      }
      return null;
    };

    TSCompiler.prototype.loadTSLintConfig = function() {
      var cfg;
      cfg = FSU.require(this.cfg.base, 'tslint.json');
      if (!cfg) {
        cfg = FSU.require(Home(), 'tslint.json');
      }
      if (!cfg) {
        cfg = FSU.require(__dirname, '..', '..', '.default.tslint.json');
      }
      if (!cfg) {
        console.log('ERROR: tslint config not found!!');
      }
      _.deepMerge(linterOptions.configuration, cfg);
      return null;
    };

    TSCompiler.prototype.addPath = function(path) {
      var file;
      file = this.fileMap[path];
      if (!file) {
        this.paths.push(path);
        this.fileMap[path] = {
          version: 0,
          path: path
        };
      } else {
        ++file.version;
      }
      return null;
    };

    TSCompiler.prototype.removePath = function(path) {
      if (this.fileMap[path]) {
        this.paths.splice(this.paths.indexOf(path), 1);
        delete this.fileMap[path];
      }
      delete this.linterMap[path];
      return null;
    };

    TSCompiler.prototype.compile = function(files) {
      var file, i, j, len, len1, path;
      this.files = [];
      for (i = 0, len = files.length; i < len; i++) {
        file = files[i];
        path = file.path;
        if (!file.removed) {
          this.addPath(path);
          this.files.push(this.fileMap[path]);
        } else {
          this.removePath(path);
        }
      }
      this.errors = [];
      if (!this.service) {
        this.createService();
      }
      if (!this.initialized || files.length > 20) {
        this.compileAll(this.paths, options);
      } else {
        this.program = this.service.getProgram();
        for (j = 0, len1 = files.length; j < len1; j++) {
          file = files[j];
          if (!file.removed) {
            this.compilePath(file.path);
          }
        }
      }
      this.compiled();
      return null;
    };

    TSCompiler.prototype.compileAll = function(paths, options) {
      var allDiagnostics, emitResult;
      this.program = ts.createProgram(paths, options);
      emitResult = this.program.emit();
      allDiagnostics = ts.getPreEmitDiagnostics(this.program).concat(emitResult.diagnostics);
      allDiagnostics.forEach((function(_this) {
        return function(diagnostic) {
          var character, line, message, ref;
          if (diagnostic.file) {
            ref = diagnostic.file.getLineAndCharacterOfPosition(diagnostic.start), line = ref.line, character = ref.character;
            message = ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n');
            return _this.errors.push({
              path: diagnostic.file.fileName,
              line: line + 1,
              col: character + 1,
              text: message
            });
          } else {
            return console.log('diagnostic without file: ', diagnostic);
          }
        };
      })(this));
      return null;
    };

    TSCompiler.prototype.compilePath = function(path) {
      var allDiagnostics, file, hasErrors, i, len, output, ref;
      if (/\.d\.ts/.test(path)) {
        return null;
      }
      output = this.service.getEmitOutput(path);
      allDiagnostics = this.service.getSyntacticDiagnostics(path).concat(this.service.getSemanticDiagnostics(path));
      hasErrors = false;
      allDiagnostics.forEach((function(_this) {
        return function(diagnostic) {
          var character, line, message, ref;
          hasErrors = false;
          if (diagnostic.file) {
            ref = diagnostic.file.getLineAndCharacterOfPosition(diagnostic.start), line = ref.line, character = ref.character;
            message = ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n');
            return _this.errors.push({
              path: diagnostic.file.fileName,
              line: line + 1,
              col: character + 1,
              text: message
            });
          } else {
            return console.log('diagnostic without file: ', diagnostic);
          }
        };
      })(this));
      if (!hasErrors || true) {
        ref = output.outputFiles;
        for (i = 0, len = ref.length; i < len; i++) {
          file = ref[i];
          FS.writeFileSync(file.name, file.text, "utf8");
        }
      }
      return null;
    };

    TSCompiler.prototype.createService = function() {
      this.servicesHost = {
        getScriptFileNames: (function(_this) {
          return function() {
            return _this.paths;
          };
        })(this),
        getScriptVersion: (function(_this) {
          return function(path) {
            return _this.fileMap[path] && _this.fileMap[path].version.toString();
          };
        })(this),
        getScriptSnapshot: function(path) {
          if (!FSU.isFile(path)) {
            return void 0;
          }
          return ts.ScriptSnapshot.fromString(FS.readFileSync(path).toString());
        },
        getCurrentDirectory: function() {
          return process.cwd();
        },
        getCompilationSettings: function() {
          return options;
        },
        getDefaultLibFileName: function(options) {
          return ts.getDefaultLibFilePath(options);
        }
      };
      this.service = ts.createLanguageService(this.servicesHost, ts.createDocumentRegistry());
      return null;
    };

    TSCompiler.prototype.lint = function() {
      var error, errors, file, i, j, k, len, len1, len2, map, path, ref, ref1, ref2;
      errors = [];
      map = {};
      ref = this.files;
      for (i = 0, len = ref.length; i < len; i++) {
        file = ref[i];
        map[file.path] = true;
      }
      ref1 = this.linterErrors;
      for (j = 0, len1 = ref1.length; j < len1; j++) {
        error = ref1[j];
        if (!map[error.path]) {
          errors.push(error);
        }
      }
      this.linterErrors = errors;
      ref2 = this.files;
      for (k = 0, len2 = ref2.length; k < len2; k++) {
        file = ref2[k];
        path = file.path;
        file = this.program.getSourceFile(path);
        this.linterMap[path] = file.text;
        this.lintFile(path);
      }
      return null;
    };

    TSCompiler.prototype.lintFile = function(path) {
      var data, i, len, linter, pos, ref, result, results;
      linter = new Linter(path, this.linterMap[path], linterOptions);
      result = linter.lint();
      ref = result.failures;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        data = ref[i];
        pos = data.startPosition.lineAndCharacter;
        results.push(this.linterErrors.push({
          path: path,
          line: pos.line + 1,
          col: pos.character + 1,
          text: data.failure
        }));
      }
      return results;
    };

    TSCompiler.prototype.compiled = function() {
      SW.start('linter');
      if (this.errors.length === 0 && (this.initialized || !this.cfg.tslint.ignoreInitial)) {
        this.lint();
      }
      console.log("linter tooks: " + (SW.stop('linter')) + "ms");
      this.initialized = true;
      if (this.errors.length) {
        console.log('ts.errors: \n', this.errors);
      }
      if (this.linterErrors.length) {
        console.log('tslint.errors: \n', this.linterErrors);
      }
      this.ipc.send('compiled', 'ts', this.errors);
      return null;
    };

    return TSCompiler;

  })();

  module.exports = new TSCompiler();

}).call(this);
