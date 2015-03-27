var SyncView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

SyncView = (function(_super) {
  __extends(SyncView, _super);

  function SyncView() {
    this.update = __bind(this.update, this);
    this.render = __bind(this.render, this);
    return SyncView.__super__.constructor.apply(this, arguments);
  }

  SyncView.prototype.initialize = function() {
    return this.sync = new Sync();
  };

  SyncView.prototype.el = '#content';

  SyncView.prototype.render = function() {
    this.$el.html("");
    return $("#log").html("");
  };

  SyncView.prototype.update = function() {
    return this.sync.fetch({
      success: (function(_this) {
        return function() {
          $(".sync-sent-status").html(_this.sync.was_last_send_successful() ? _this.sync.last_send_time() : (_this.sync.last_send_time()) + " - last attempt FAILED");
          return $(".sync-get-status").html(_this.sync.was_last_get_successful() ? _this.sync.last_get_time() : (_this.sync.last_get_time()) + " - last attempt FAILED");
        };
      })(this),
      error: (function(_this) {
        return function() {
          console.log("synclog doesn't exist yet, create it and re-render");
          _this.sync.save();
          return _.delay(_this.update, 1000);
        };
      })(this)
    });
  };

  return SyncView;

})(Backbone.View);
