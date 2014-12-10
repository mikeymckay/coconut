var UsersView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

UsersView = (function(_super) {
  __extends(UsersView, _super);

  function UsersView() {
    this.render = __bind(this.render, this);
    return UsersView.__super__.constructor.apply(this, arguments);
  }

  UsersView.prototype.initialize = function() {
    return this.userCollection = new UserCollection();
  };

  UsersView.prototype.el = '#content';

  UsersView.prototype.events = {
    "submit form#user": "save",
    "click .loadUser": "load",
    "click #cancel": "cancel",
    "click #new": "newUser"
  };

  UsersView.prototype.cancel = function() {
    return $("#edit-user").hide();
  };

  UsersView.prototype.newUser = function() {
    $("input").val("");
    return $("#edit-user").show();
  };

  UsersView.prototype.save = function() {
    var hideEditorUpdateTable, user, userData;
    userData = $('form#user').toObject({
      skipEmpty: false
    });
    userData._id = "user." + userData._id;
    if (userData.inactive === 'on') {
      userData.inactive = true;
    }
    userData.isApplicationDoc = true;
    if (userData.district != null) {
      userData.district = userData.district.toUpperCase();
    }
    user = new User({
      _id: userData._id
    });
    hideEditorUpdateTable = (function(_this) {
      return function() {
        return user.save(userData, {
          success: function() {
            _this.render();
            return $("#edit-user").hide();
          }
        });
      };
    })(this);
    user.fetch({
      success: (function(_this) {
        return function() {
          return hideEditorUpdateTable();
        };
      })(this),
      error: (function(_this) {
        return function() {
          return hideEditorUpdateTable();
        };
      })(this)
    });
    return false;
  };

  UsersView.prototype.load = function(event) {
    var user;
    $("#edit-user").show();
    user = new User({
      _id: $(event.target).closest("a").attr("data-user-id")
    });
    user.fetch({
      success: (function(_this) {
        return function() {
          user.set({
            _id: user.get("_id").replace(/user\./, "")
          });
          return js2form($('form#user').get(0), user.toJSON());
        };
      })(this)
    });
    return false;
  };

  UsersView.prototype.render = function() {
    var fields;
    fields = "_id,password,district,name,comments".split(",");
    this.$el.html("<div style='display:none' id='edit-user'> <h2>Create/edit users</h2> <ul> <li>DMSO's must have a username that corresponds to their phone number.</li> <li>If a DMSO is no longer working, mark their account as inactive to stop notification messages from being sent.</li> </ul> <form id='user'> " + (_.map(fields, function(field) {
      return "<label style='display:block' for='" + field + "'>" + (field === "_id" ? "Username" : field.humanize()) + "</label> <input id='" + field + "' name='" + field + "' type='text'></input>";
    }).join("")) + " <label style='display:block' for='inactive'>Inactive</label> <input id='inactive' name='inactive' type='checkbox'></input> <input type='submit' value='Save'></input> <button id='cancel' type='button'>Cancel</button> </form> </div> <h2>Click username to edit</h2> <button id='new' type='button'>Create new user</button> <br/> <br/> <table> <thead> <tr> " + (fields.push("inactive"), _.map(fields, function(field) {
      return "<th>" + (field === "_id" ? "Username" : field.humanize()) + "</th>";
    }).join("")) + " </tr> </thead> <tbody> </tbody> </table>");
    return this.userCollection.fetch({
      success: (function(_this) {
        return function() {
          _this.userCollection.sortBy(function(user) {
            return user.get("_id");
          }).forEach(function(user) {
            return $("tbody").append("<tr> " + (_.map(fields, function(field) {
              var data;
              data = user.get(field) || '-';
              if (field === "_id") {
                return "<td><a class='loadUser' data-user-id='" + (user.get("_id")) + "' href=''>" + (data.replace(/user\./, "")) + "</a></td>";
              } else {
                return "<td>" + data + "</td>";
              }
            }).join("")) + " </tr>");
          });
          $("a").button();
          return $('table').dataTable();
        };
      })(this)
    });
  };

  return UsersView;

})(Backbone.View);
