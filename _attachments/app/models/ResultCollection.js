var ResultCollection,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ResultCollection = (function(_super) {
  __extends(ResultCollection, _super);

  function ResultCollection() {
    return ResultCollection.__super__.constructor.apply(this, arguments);
  }

  ResultCollection.prototype.model = Result;

  ResultCollection.prototype.url = '/result';

  ResultCollection.prototype.db = {
    view: "resultsByQuestionAndComplete"
  };

  ResultCollection.prototype.fetch = function(options) {
    if (options != null ? options.question : void 0) {
      options.startkey = options.question + ":z";
      options.endkey = options.question;
      options.descending = "true";
      if (options.isComplete === "trueAndFalse") {
        this.db.view = "resultsByQuestion";
        if (options.startTime != null) {
          options.startkey = options.question + ":" + options.startTime;
          options.endkey = options.question;
          options.descending = "true";
          if (options.endTime != null) {
            options.startkey = options.question + ":" + options.startTime;
            options.endkey = options.question + ":" + options.endTime;
            options.descending = "true";
          }
        }
      } else if (options.isComplete != null) {
        options.startkey = options.question + ":" + options.isComplete + ":z";
        options.endkey = options.question + ":" + options.isComplete;
        options.descending = "true";
        if (options.startTime != null) {
          options.startkey = options.question + ":" + options.isComplete + ":" + options.startTime;
          options.endkey = options.question + ":" + options.isComplete;
          options.descending = "true";
          if (options.endTime != null) {
            options.startkey = options.question + ":" + options.isComplete + ":" + options.startTime;
            options.endkey = options.question + ":" + options.isComplete + ":" + options.endTime;
            options.descending = "true";
          }
        }
      }
    }
    return ResultCollection.__super__.fetch.call(this, options);
  };

  ResultCollection.prototype.filteredByQuestionCategorizedByStatus = function(questionType) {
    var returnObject;
    returnObject = {};
    returnObject.complete = [];
    returnObject.notCompete = [];
    this.each(function(result) {
      if (result.get("question") !== questionType) {
        return;
      }
      switch (result.get("complete")) {
        case true:
          return returnObject.complete.push(result);
        default:
          return returnObject.notComplete.push(result);
      }
    });
    return returnObject;
  };

  ResultCollection.prototype.filterByQuestionType = function(questionType) {
    return this.filter(function(result) {
      return result.get("question") === questionType;
    });
  };

  ResultCollection.prototype.partialResults = function(questionType) {
    return this.filter(function(result) {
      return result.get("question") === questionType && !result.complete();
    });
  };

  return ResultCollection;

})(Backbone.Collection);
