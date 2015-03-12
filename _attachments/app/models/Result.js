var Result,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Result = (function(_super) {
  __extends(Result, _super);

  function Result() {
    return Result.__super__.constructor.apply(this, arguments);
  }

  Result.prototype.initialize = function() {
    if (!this.attributes.createdAt) {
      this.set({
        createdAt: moment(new Date()).format(Coconut.config.get("date_format"))
      });
    }
    if (!this.attributes.lastModifiedAt) {
      return this.set({
        lastModifiedAt: moment(new Date()).format(Coconut.config.get("date_format"))
      });
    }
  };

  Result.prototype.url = "/result";

  Result.prototype.question = function() {
    return this.get("question");
  };

  Result.prototype.tags = function() {
    var tags;
    tags = this.get("Tags");
    if (tags != null) {
      return tags.split(/, */);
    }
    return [];
  };

  Result.prototype.complete = function() {
    var complete;
    if (_.include(this.tags(), "complete")) {
      return true;
    }
    complete = this.get("complete");
    if (typeof complete === "undefined") {
      complete = this.get("Complete");
    }
    if (complete === null || typeof complete === "undefined") {
      return false;
    }
    if (complete === true || complete.match(/true|yes/)) {
      return true;
    }
  };

  Result.prototype.shortString = function() {
    var result;
    result = this.string;
    if (result.length > 40) {
      return result.substring(0, 40) + "...";
    } else {
      return result;
    }
  };

  Result.prototype.summaryKeys = function(question) {
    var relevantKeys;
    relevantKeys = question.summaryFieldKeys();
    if (relevantKeys.length === 0) {
      relevantKeys = _.difference(_.keys(result.toJSON()), ["_id", "_rev", "complete", "question", "collection"]);
    }
    return relevantKeys;
  };

  Result.prototype.summaryValues = function(question) {
    return _.map(this.summaryKeys(question), (function(_this) {
      return function(key) {
        var returnVal;
        returnVal = _this.get(key) || "";
        if (typeof returnVal === "object") {
          returnVal = JSON.stringify(returnVal);
        }
        return returnVal;
      };
    })(this));
  };

  Result.prototype.get = function(attribute) {
    var original;
    if (User.currentUser == null) {
      return null;
    }
    original = Result.__super__.get.call(this, attribute);
    if (User.currentUser.hasRole("cleaner")) {
      return original;
    }
    if ((original != null) && User.currentUser.hasRole("reports")) {
      if (_.contains(Coconut.identifyingAttributes, attribute)) {
        return b64_sha1(original);
      }
    }
    return original;
  };

  Result.prototype.toJSON = function() {
    var json;
    json = Result.__super__.toJSON.call(this);
    if (User.currentUser.hasRole("admin")) {
      return json;
    }
    if (User.currentUser.hasRole("reports")) {
      _.each(json, (function(_this) {
        return function(value, key) {
          if ((value != null) && _.contains(Coconut.identifyingAttributes, key)) {
            return json[key] = b64_sha1(value);
          }
        };
      })(this));
    }
    return json;
  };

  Result.prototype.save = function(key, value, options) {
    this.set({
      user: $.cookie('current_user'),
      lastModifiedAt: moment(new Date()).format(Coconut.config.get("date_format"))
    });
    return Result.__super__.save.call(this, key, value, options);
  };

  Result.prototype.wasTransferredOut = function() {
    var transferred, transferredTo;
    transferred = this.get("transferred");
    if (transferred != null) {
      transferredTo = transferred[transferred.length - 1].to;
      if (transferredTo !== User.currentUser.id) {
        return true;
      }
    }
    return false;
  };

  return Result;

})(Backbone.Model);
