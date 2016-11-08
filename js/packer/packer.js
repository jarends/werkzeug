// Generated by CoffeeScript 1.10.0
(function() {
  var CHUNK_CODE, Dict, FS, IPC, Indexer, PACK_CODE, Packer, Path, Reg, getChunkCode, getPackCode, nga,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    slice = [].slice;

  FS = require('fs');

  Path = require('path');

  nga = require('ng-annotate/ng-annotate-main');

  Dict = require('jsdictionary');

  Reg = require('../utils/regex');

  IPC = require('../utils/ipc');

  PACK_CODE = FS.readFileSync(Path.join(__dirname, 'pack.js'), 'utf8');

  CHUNK_CODE = FS.readFileSync(Path.join(__dirname, 'chunk.js'), 'utf8');

  getPackCode = function(p) {
    return "var ENV = '';\nvar HMR = false;\n(function(pack)\n{\n    var cfg = {\n        index:      " + p.index + ",\n        total:      " + p.total + ",\n        startIndex: " + p.file.index + ",\n        type:       'register::" + p.id + "',\n        path:       '" + p.file.path + "',\n        pack:       pack\n    };\n    var packer = " + (p.index === 0 ? PACK_CODE : CHUNK_CODE) + "\n    packer.init(cfg);\n\n})({\n" + p.code + "\n});";
  };

  getChunkCode = function(p) {
    return "(function(pack)\n{\n    var cfg = {\n        type:       'register::" + p.id + "',\n        path:       '" + p.file.path + "',\n        chunk:      '" + p.chunk + "',\n        pack:       pack\n    };\n    var chunk = " + CHUNK_CODE + "\n    chunk.init(cfg);\n\n})({\n" + p.code + "\n});";
  };

  Indexer = (function() {
    function Indexer() {
      this.current = -1;
      this.free = [];
    }

    Indexer.prototype.get = function() {
      if (this.free.length) {
        return this.free.shift();
      }
      return ++this.current;
    };

    Indexer.prototype.remove = function(index) {
      if (this.free.indexOf(index) === -1) {
        this.free.unshift(index);
      }
      return null;
    };

    return Indexer;

  })();

  Packer = (function() {
    function Packer() {
      this.completed = bind(this.completed, this);
      this.indexer = new Indexer();
      this.fileMap = {};
      this.nodes = {};
      this.loaders = {};
      this.openFiles = 0;
      this.openPacks = 0;
      this.packed = null;
      this.loaded = null;
      this.ipc = new IPC(process, this);
    }

    Packer.prototype.init = function(cfg1) {
      this.cfg = cfg1;
      this.id = Math.random() + '_' + Date.now();
      this.nga = this.cfg.packer.nga || false;
      return null;
    };

    Packer.prototype.readPackages = function() {
      var cfg, j, len, packages, path, ref, root;
      packages = ((ref = this.cfg.packer) != null ? ref.packages : void 0) || [];
      root = Path.join(this.cfg.base, this.cfg.tmp, this.cfg.root);
      for (j = 0, len = packages.length; j < len; j++) {
        cfg = packages[j];
        path = Path.join(root, cfg["in"]);
        this.readFile(Reg.correctOut(path));
      }
      return null;
    };

    Packer.prototype.update = function(files) {
      var base, f, file, j, len, path, tmp;
      console.log('packer.update: ', files);
      base = this.cfg.base;
      tmp = Path.join(base, this.cfg.tmp);
      for (j = 0, len = files.length; j < len; j++) {
        f = files[j];
        path = Reg.correctTmp(Reg.correctOut(f.path), base, tmp);
        console.log('update: ', path);
        file = this.fileMap[path];
        if (file) {
          if (file.removed) {
            this.remove(file);
          } else {
            this.clear(file);
          }
        }
      }
      if (this.openFiles === 0) {
        this.completed();
      }
      return null;
    };

    Packer.prototype.remove = function(file) {
      var j, len, parent, path, ppath, ref;
      this.clear(file, false);
      path = file.path;
      ref = file.ref;
      for (j = 0, len = ref.length; j < len; j++) {
        ppath = ref[j];
        parent = this.fileMap[ppath];
        delete parent.req[path];
        delete file.ref[ppath];
      }
      return null;
    };

    Packer.prototype.clear = function(file, read) {
      var loaderRefs, path, rfile, rpath;
      if (read == null) {
        read = true;
      }
      path = file.path;
      for (rpath in file.req) {
        rfile = this.fileMap[rpath];
        delete rfile.ref[path];
        delete file.req[rpath];
      }
      for (rpath in file.reqAsL) {
        loaderRefs = this.loaders[rpath];
        if (loaderRefs) {
          delete loaderRefs[path];
          if (!Dict.hasKeys(loaderRefs)) {
            delete this.loaders[rpath];
          }
        }
        delete file.reqAsL[rpath];
      }
      this.fileMap[path] = null;
      this.indexer.remove(file.index);
      if (read) {
        this.readFile(path);
      }
      return null;
    };

    Packer.prototype.completed = function() {
      this.ipc.send('packed', []);
      return null;
    };

    Packer.prototype.writePackages = function() {
      var chunk, dest, file, i, j, k, l, len, loader, p, pack, packages, packs, path;
      this.packed = {};
      this.loaded = {};
      packages = this.cfg.packer.packages || [];
      dest = Path.join(this.cfg.base, this.cfg.tmp, this.cfg.root);
      l = packages.length;
      packs = [];
      for (path in this.fileMap) {
        file = this.fileMap[path];
        file.loaders = {};
        file.parts = {};
      }
      for (i = j = packages.length - 1; j >= 0; i = j += -1) {
        pack = packages[i];
        path = Path.join(dest, pack["in"]);
        file = this.fileMap[path];
        p = {
          file: file,
          index: i,
          total: l,
          id: this.id,
          out: Path.join(dest, pack.out),
          req: {},
          loaders: {},
          code: ''
        };
        packs.push(p);
        this.gatherReq(p, file);
      }
      for (path in this.loaders) {
        loader = this.fileMap[path];
        this.gatherChunks(loader, loader);
      }
      for (path in this.loaded) {
        this.cleanUpChunks(this.fileMap[path], packs);
      }
      for (k = 0, len = packs.length; k < len; k++) {
        p = packs[k];
        this.writePack(p);
      }
      for (path in this.loaders) {
        loader = this.fileMap[path];
        chunk = this.getChunkPath(loader);
        p = {
          file: loader,
          id: this.id,
          out: Path.join(dest, chunk),
          chunk: chunk,
          code: ''
        };
        this.writeChunk(p);
      }
      return null;
    };

    Packer.prototype.getChunkPath = function(loader) {
      return this.cfg.packer.chunks + loader.index + '.js';
    };

    Packer.prototype.gatherReq = function(p, file) {
      var path, rfile;
      if (this.packed[file.index]) {
        return null;
      }
      this.packed[file.index] = true;
      p.req[file.path] = true;
      for (path in file.req) {
        rfile = this.fileMap[path];
        if (rfile && !this.packed[rfile.index]) {
          if (!(this.loaders[path] && file.reqAsL[path])) {
            this.gatherReq(p, rfile);
          } else {
            p.loaders[path] = true;
          }
        }
      }
      return null;
    };

    Packer.prototype.gatherChunks = function(loader, file) {
      var path, rfile;
      file.loaders[loader.path] = true;
      loader.parts[file.path] = true;
      this.loaded[file.path] = true;
      for (path in file.req) {
        rfile = this.fileMap[path];
        if (!loader.parts[rfile.path]) {
          this.gatherChunks(loader, rfile);
        }
      }
      return null;
    };

    Packer.prototype.cleanUpChunks = function(file, packs) {
      var j, len, loader, lpath, p, packed, path;
      loader = this.getLoader(file);
      path = file.path;
      packed = this.packed[file.index];
      if (packed || !loader) {
        for (lpath in file.loaders) {
          loader = this.fileMap[lpath];
          delete loader.parts[path];
          delete file.loaders[lpath];
          if (!packed) {
            for (j = 0, len = packs.length; j < len; j++) {
              p = packs[j];
              if (p.loaders[lpath]) {
                p.req[path] = true;
                packed = true;
                break;
              }
            }
          }
        }
      }
      return null;
    };

    Packer.prototype.getLoader = function(file) {
      var count, path;
      count = 0;
      for (path in file.loaders) {
        ++count;
        if (count > 1) {
          return null;
        }
      }
      return this.fileMap[path];
    };

    Packer.prototype.writePack = function(p) {
      var path;
      for (path in p.req) {
        this.addPackSrc(p, this.fileMap[path]);
      }
      p.code = p.code.slice(0, -3);
      p.code = getPackCode(p);
      ++this.openPacks;
      FS.writeFile(p.out, p.code, 'utf8', (function(_this) {
        return function(error) {
          --_this.openPacks;
          if (error) {
            console.log('packer.writePack: pack write error: ', p.out);
          }
          if (_this.openPacks === 0) {
            _this.completed();
          }
          return null;
        };
      })(this));
      return null;
    };

    Packer.prototype.writeChunk = function(p) {
      var path;
      for (path in p.file.parts) {
        this.addPackSrc(p, this.fileMap[path]);
      }
      p.code = p.code.slice(0, -3);
      p.code = getChunkCode(p);
      ++this.openPacks;
      FS.writeFile(p.out, p.code, 'utf8', (function(_this) {
        return function(error) {
          --_this.openPacks;
          if (error) {
            console.log('packer.writeChunk: chunk write error: ', p.out);
          }
          if (_this.openPacks === 0) {
            _this.completed();
          }
          return null;
        };
      })(this));
      return null;
    };

    Packer.prototype.addPackSrc = function(p, file) {
      var code, source, str;
      source = file.source;
      if (this.nga) {
        source = nga(source, {
          add: true
        }).src;
      }
      code = "// " + file.path + "\r\n" + file.index + ": ";
      if (/.js$/.test(file.path)) {
        code += "function(module, exports, require) {\r\n" + source + "\r\n},\r\n";
      } else {
        str = source.replace(/'/g, '\\\'').replace(/\r\n|\n/g, '\\n');
        if (/.html$/.test(file.path)) {
          str = str.replace(/\${\s*(require\s*\(\s*\d*?\s*\))\s*}/g, '\' + $1 + \'');
        }
        code += "function(module, exports, require) {\r\nmodule.exports = '" + str + "';\r\n},\r\n";
      }
      p.code += code;
      return null;
    };

    Packer.prototype.readFile = function(path, parent) {
      var file;
      file = this.fileMap[path];
      if (file) {
        if (parent) {
          parent.req[path] = true;
          file.ref[parent.path] = true;
        }
        return file;
      }
      file = this.fileMap[path] = {
        index: this.indexer.get(),
        path: path,
        source: '',
        ref: {},
        req: {},
        reqAsL: {},
        error: false
      };
      if (parent) {
        parent.req[path] = true;
        file.ref[parent.path] = true;
      }
      ++this.openFiles;
      FS.readFile(path, 'utf8', (function(_this) {
        return function(error, source) {
          --_this.openFiles;
          if (error) {
            file.error = error;
            console.log('packer.readFile: not found: ', path);
          } else {
            file.source = source;
            _this.parseFile(file);
          }
          if (_this.openFiles === 0) {
            _this.writePackages();
          }
          return null;
        };
      })(this));
      return file;
    };

    Packer.prototype.parseFile = function(file) {
      var base, regex;
      base = Path.dirname(file.path);
      regex = /require\s*\(\s*('|")(.*?)('|")\s*\)/g;
      file.source = file.source.replace(regex, (function(_this) {
        return function() {
          var args, isLoader, isRel, loaderRefs, name, pathObj, rfile, rpath;
          args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
          name = Reg.correctOut(args[2]);
          isLoader = /^es6-promise\!/.test(name);
          if (isLoader) {
            name = name.replace(/^es6-promise\!/, '');
          }
          isRel = /\.|\//.test(name[0]);
          if (isRel) {
            pathObj = _this.getRelModulePath(base, name);
          } else {
            pathObj = _this.getNodeModulePath(base, name);
            if (pathObj && !_this.nodes[pathObj.path]) {
              _this.nodes[pathObj.path] = true;
            }
          }
          if (pathObj) {
            rfile = _this.readFile(pathObj.path, file);
            if (pathObj.main) {
              rfile.modulePath = pathObj.modulePath;
              rfile.main = pathObj.main;
            }
            if (isLoader) {
              rpath = rfile.path;
              loaderRefs = _this.loaders[rpath] || (_this.loaders[rpath] = {});
              loaderRefs[file.path] = true;
              file.reqAsL[rpath] = true;
              return "require(" + rfile.index + ", '" + (_this.getChunkPath(rfile)) + "')";
            }
            return "require(" + rfile.index + ")";
          } else {
            console.log('packer.parseFile: module "' + name + '" not found - required by: ' + file.path);
          }
          return args[0];
        };
      })(this));
      return null;
    };

    Packer.prototype.getRelModulePath = function(base, moduleName) {
      var ext, file, path;
      ext = this.getExt(moduleName, '.js');
      path = Path.join(base, moduleName);
      if (this.isFile(file = path + ext)) {
        return {
          path: file
        };
      }
      if (this.isFile(file = Path.join(path, 'index.js'))) {
        return {
          path: file
        };
      }
      if (ext && this.isFile(path)) {
        return {
          path: path
        };
      }
      return null;
    };

    Packer.prototype.getNodeModulePath = function(base, moduleName) {
      var error1, ext, file, json, main, modulePath, nodePath;
      nodePath = Path.join(base, '/node_modules');
      modulePath = Path.join(nodePath, moduleName);
      if (this.isDir(nodePath)) {
        ext = this.getExt(moduleName, '.js');
        if (this.isFile(file = modulePath + ext)) {
          return {
            path: file
          };
        }
        if (this.isFile(file = Path.join(modulePath, '/package.json'))) {
          try {
            json = require(file);
            main = json != null ? json.main : void 0;
          } catch (error1) {

          }
          if (main && this.isFile(file = Path.join(modulePath, main))) {
            return {
              path: file,
              modulePath: modulePath,
              main: main
            };
          }
        }
        if (this.isFile(file = Path.join(modulePath, 'index.js'))) {
          return {
            path: file
          };
        }
      }
      if (base !== this.cfg.base) {
        return this.getNodeModulePath(Path.resolve(base, '..'), moduleName);
      }
      return null;
    };

    Packer.prototype.getExt = function(name, ext) {
      if (new RegExp(ext + '$').test(name)) {
        return '';
      }
      return ext;
    };

    Packer.prototype.isDir = function(path) {
      var stat;
      stat = this.getStat(path);
      if (stat != null ? stat.isDirectory() : void 0) {
        return true;
      }
      return false;
    };

    Packer.prototype.isFile = function(path) {
      var stat;
      stat = this.getStat(path);
      if (stat != null ? stat.isFile() : void 0) {
        return true;
      }
      return false;
    };

    Packer.prototype.getStat = function(path) {
      var error, error1;
      try {
        return FS.statSync(path);
      } catch (error1) {
        error = error1;
        return null;
      }
    };

    Packer.prototype.exit = function() {
      return null;
    };

    return Packer;

  })();

  module.exports = new Packer();

}).call(this);

//# sourceMappingURL=packer.js.map