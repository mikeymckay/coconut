var MenuView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

MenuView = (function(_super) {
  __extends(MenuView, _super);

  function MenuView() {
    this.checkReplicationStatus = __bind(this.checkReplicationStatus, this);
    this.render = __bind(this.render, this);
    return MenuView.__super__.constructor.apply(this, arguments);
  }

  MenuView.prototype.el = '.question-buttons';

  MenuView.prototype.events = {
    "change": "render"
  };

  MenuView.prototype.render = function() {
    this.$el.html("<div id='navbar' data-role='navbar'> <ul></ul> </div>");
    this.checkReplicationStatus();
    return Coconut.questions.fetch({
      success: (function(_this) {
        return function() {
          _this.$el.find("ul").html(Coconut.questions.map(function(question, index) {
            return "<li><a id='menu-" + index + "' href='#show/results/" + (escape(question.id)) + "'><h2>" + question.id + "<div id='menu-partial-amount'></div></h2></a></li>";
          }).join(" "));
          _this.$el.find("ul").append("<li><a id='menu-summary' href='#summary'><h2>Summary</h2></a></li>");
          $(".question-buttons").navbar();
          return _this.update();
        };
      })(this)
    });
  };

  MenuView.prototype.update = function() {
    if (Coconut.config.local.get("mode") === "mobile") {
      User.isAuthenticated({
        success: function() {
          return Coconut.questions.each((function(_this) {
            return function(question, index) {
              return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/resultsByQuestionNotCompleteNotTransferredOut", {
                key: question.id,
                include_docs: false,
                error: function(result) {
                  return _this.log("Could not retrieve list of results: " + (JSON.stringify(error)));
                },
                success: function(result) {
                  var total;
                  total = 0;
                  _(result.rows).each(function(row) {
                    var transferredTo;
                    transferredTo = row.value;
                    if (transferredTo != null) {
                      if (User.currentUser.id === transferredTo) {
                        return total += 1;
                      }
                    } else {
                      return total += 1;
                    }
                  });
                  return $("#menu-" + index + " #menu-partial-amount").html(total);
                }
              });
            };
          })(this));
        }
      });
    }
    return $.ajax("/" + (Coconut.config.database_name()) + "/version", {
      dataType: "json",
      success: function(result) {
        return $("#version").html(result.version);
      },
      error: $("#version").html("-")
    });
  };

  MenuView.prototype.checkReplicationStatus = function() {
    return;
    return $.couch.login({
      name: Coconut.config.get("local_couchdb_admin_username"),
      password: Coconut.config.get("local_couchdb_admin_password"),
      error: (function(_this) {
        return function() {
          return console.log("Could not login");
        };
      })(this),
      complete: (function(_this) {
        return function() {
          return $.ajax({
            url: "/_active_tasks",
            dataType: 'json',
            success: function(response) {
              var progress, _ref;
              progress = response != null ? (_ref = response[0]) != null ? _ref.progress : void 0 : void 0;
              if (progress) {
                $("#databaseStatus").html("" + progress + "% Complete");
                return _.delay(_this.checkReplicationStatus, 1000);
              } else {
                $("#databaseStatus").html("");
                return _.delay(_this.checkReplicationStatus, 60000);
              }
            },
            error: function(error) {
              console.log("Could not check active_tasks: " + (JSON.stringify(error)));
              return _.delay(_this.checkReplicationStatus, 60000);
            }
          });
        };
      })(this)
    });
  };

  return MenuView;

})(Backbone.View);
