var QuestionCollection,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

QuestionCollection = (function(_super) {
  __extends(QuestionCollection, _super);

  function QuestionCollection() {
    return QuestionCollection.__super__.constructor.apply(this, arguments);
  }

  QuestionCollection.prototype.model = Question;

  QuestionCollection.prototype.url = '/question';

  return QuestionCollection;

})(Backbone.Collection);
