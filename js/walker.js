// Generated by CoffeeScript 1.10.0
(function() {
  var EMap, Walk, Walker, options;

  Walk = require('walkdir');

  EMap = require('emap');

  options = {
    follow_symlinks: false,
    no_recurse: false,
    max_depth: void 0
  };

  Walker = (function() {
    function Walker(wz) {
      this.wz = wz;
      this.cfg = this.wz.cfg;
      this.options = options;
      this.emap = new EMap();
    }

    Walker.prototype.walk = function() {
      console.log('walk');
      if (this.w) {
        this.w.end();
        this.emap.all();
      }
      this.w = Walk(this.cfg.base, this.options);
      this.emap.map(this.w, 'path', this.pathHandler, this);
      this.emap.map(this.w, 'end', this.endHandler, this);
      return null;
    };

    Walker.prototype.pathHandler = function(path, stat) {
      var ignore;
      ignore = this.wz.ignore(path);
      if (stat.isDirectory()) {
        if (ignore) {
          this.w.ignore(path);
        }
      } else if (!ignore) {
        this.wz.fileAdded(path);
      }
      return null;
    };

    Walker.prototype.endHandler = function() {
      this.wz.walked();
      return null;
    };

    return Walker;

  })();

  module.exports = Walker;

}).call(this);

//# sourceMappingURL=walker.js.map