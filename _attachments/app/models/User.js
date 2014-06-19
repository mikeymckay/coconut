var User, UserCollection,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

User = (function(_super) {
  __extends(User, _super);

  function User() {
    return User.__super__.constructor.apply(this, arguments);
  }

  User.prototype.url = "/user";

  User.prototype.username = function() {
    return this.get("_id").replace(/^user\./, "");
  };

  User.prototype.district = function() {
    return this.get("district");
  };

  User.prototype.passwordIsValid = function(password) {
    return this.get("password") === password;
  };

  User.prototype.isAdmin = function() {
    return _(this.get("roles")).include("admin");
  };

  User.prototype.hasRole = function(role) {
    return _(this.get("roles")).include(role);
  };

  User.prototype.login = function() {
    User.currentUser = this;
    $.cookie('current_user', this.username());
    $("span#user").html(this.username());
    $('#district').html(this.get("district"));
    $("a[href=#logout]").show();
    $("a[href=#login]").hide();
    if (this.isAdmin()) {
      $("#manage-button").show();
    } else {
      $("#manage-button").hide();
    }
    if (this.hasRole("reports")) {
      $("#top-menu").hide();
      $("#bottom-menu").hide();
      return $.couch.db(Coconut.config.database_name()).saveDoc({
        collection: "login",
        user: this.username(),
        date: moment(new Date()).format(Coconut.config.get("date_format"))
      });
    }
  };

  User.prototype.refreshLogin = function() {
    return this.login();
  };

  return User;

})(Backbone.Model);

User.isAuthenticated = function(options) {
  var current_user_cookie, user;
  current_user_cookie = $.cookie('current_user');
  if ((current_user_cookie != null) && current_user_cookie !== "") {
    user = new User({
      _id: "user." + ($.cookie('current_user'))
    });
    return user.fetch({
      success: (function(_this) {
        return function() {
          user.refreshLogin();
          return options.success(user);
        };
      })(this),
      error: function(error) {
        console.error("Could not fetch user." + ($.cookie('current_user')) + ": " + error);
        return options != null ? options.error() : void 0;
      }
    });
  } else {
    if (options.error != null) {
      return options.error();
    }
  }
};

User.logout = function() {
  $.cookie('current_user', "");
  $("span#user").html("");
  $('#district').html("");
  $("a[href=#logout]").hide();
  $("a[href=#login]").show();
  return User.currentUser = null;
};

UserCollection = (function(_super) {
  __extends(UserCollection, _super);

  function UserCollection() {
    return UserCollection.__super__.constructor.apply(this, arguments);
  }

  UserCollection.prototype.model = User;

  UserCollection.prototype.url = '/user';

  return UserCollection;

})(Backbone.Collection);
