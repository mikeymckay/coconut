var QuestionView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

QuestionView = (function(_super) {

  __extends(QuestionView, _super);

  function QuestionView() {
    this.render = __bind(this.render, this);
    QuestionView.__super__.constructor.apply(this, arguments);
  }

  QuestionView.prototype.initialize = function() {
    var _ref;
    return (_ref = Coconut.resultCollection) != null ? _ref : Coconut.resultCollection = new ResultCollection();
  };

  QuestionView.prototype.el = $('#content');

  QuestionView.prototype.render = function() {
    var tagSelector;
    this.el.html("      <div style='display:none' id='messageText'>        Saving...      </div>      <div id='question-view'>        <form>          " + (this.toHTMLForm(this.model)) + "        </form>      </div>    ");
    js2form($('form').get(0), this.result.toJSON());
    this.updateCheckboxes();
    tagSelector = "input[name=Tags],input[name=tags]";
    $(tagSelector).tagit({
      availableTags: ["complete"],
      onTagChanged: function() {
        return $(tagSelector).trigger('change');
      }
    });
    _.each($("input[data-autocomplete-options]"), function(element) {
      element = $(element);
      return element.autocomplete({
        source: element.attr("data-autocomplete-options").split(/, */)
      });
    });
    return _.each($("input[type='autocomplete from previous entries']"), function(element) {
      element = $(element);
      return element.autocomplete({
        source: document.location.pathname.substring(0, document.location.pathname.indexOf("index.html")) + ("_list/values/byValue?key=\"" + (element.attr("name")) + "\"")
      });
    });
  };

  QuestionView.prototype.events = {
    "change #question-view input[type=checkbox]": "updateCheckboxes",
    "change #question-view input": "save",
    "change #question-view select": "save",
    "click #question-view button:contains(+)": "repeat"
  };

  QuestionView.prototype.updateCheckboxes = function() {
    $('input[type=checkbox]:checked').siblings("label").find("span").html("&#x2611;");
    return $('input[type=checkbox]').not(':checked').siblings("label").find("span").html("&#x2610;");
  };

  QuestionView.prototype.save = function() {
    var _this = this;
    this.result.save($('form').toObject({
      skipEmpty: false
    }));
    $("#messageText").slideDown().fadeOut();
    this.key = "MalariaCaseID";
    if (this.result.complete()) {
      return Coconut.resultCollection.fetch({
        success: function() {
          var result;
          switch (_this.result.get('question')) {
            case "Case Notification":
              if (!_this.currentKeyExistsInResultsFor('Facility')) {
                result = new Result({
                  question: "Facility",
                  MalariaCaseID: _this.result.get("MalariaCaseID"),
                  FacilityName: _this.result.get("FacilityName")
                });
                return result.save();
              }
              break;
            case "Facility":
              if (!_this.currentKeyExistsInResultsFor('Household')) {
                result = new Result({
                  question: "Household",
                  MalariaCaseID: _this.result.get("MalariaCaseID"),
                  HeadofHouseholdName: _this.result.get("HeadofHouseholdName")
                });
                return result.save();
              }
              break;
            case "Household":
              if (!_this.currentKeyExistsInResultsFor('HouseholdMembers')) {
                return _(_this.result.get("TotalNumberofResidentsintheHouseholdAvailableforInterview")).times(function() {
                  result = new Result({
                    question: "Household Members",
                    MalariaCaseID: _this.result.get("MalariaCaseID"),
                    HeadofHouseholdName: _this.result.get("HeadofHouseholdName")
                  });
                  return result.save();
                });
              }
          }
        }
      });
    }
  };

  QuestionView.prototype.currentKeyExistsInResultsFor = function(question) {
    var _this = this;
    return Coconut.resultCollection.any(function(result) {
      return _this.result.get(_this.key) === result.get(_this.key) && result.get('question') === question;
    });
  };

  QuestionView.prototype.repeat = function(event) {
    var button, inputElement, name, newIndex, newQuestion, questionID, re, _i, _len, _ref;
    button = $(event.target);
    newQuestion = button.prev(".question").clone();
    questionID = newQuestion.attr("data-group-id");
    if (questionID == null) questionID = "";
    _ref = newQuestion.find("input");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      inputElement = _ref[_i];
      inputElement = $(inputElement);
      name = inputElement.attr("name");
      re = new RegExp("" + questionID + "\\[(\\d)\\]");
      newIndex = parseInt(_.last(name.match(re))) + 1;
      inputElement.attr("name", name.replace(re, "" + questionID + "[" + newIndex + "]"));
    }
    button.after(newQuestion.add(button.clone()));
    return button.remove();
  };

  QuestionView.prototype.toHTMLForm = function(questions, groupId) {
    var _this = this;
    if (questions == null) questions = this.model;
    if (questions.length == null) questions = [questions];
    return _.map(questions, function(question) {
      var name, newGroupId, question_id, repeatable, result;
      if (question.repeatable() === "true") {
        repeatable = "<button>+</button>";
      } else {
        repeatable = "";
      }
      if ((question.type() != null) && (question.label() != null) && question.label() !== "") {
        name = question.label().replace(/[^a-zA-Z0-9 -]/g, "").replace(/[ -]/g, "");
        question_id = question.get("id");
        if (question.repeatable() === "true") {
          name = name + "[0]";
          question_id = question.get("id") + "-0";
        }
        if (groupId != null) name = "group." + groupId + "." + name;
        result = "          <div class='question'>" + (!question.type().match(/hidden/) ? "<label type='" + (question.type()) + "' for='" + question_id + "'>" + (question.label()) + " <span></span></label>" : void 0) + "        ";
        result += (function() {
          switch (question.type()) {
            case "textarea":
              return "<textarea name='" + name + "' id='" + question_id + "'>" + (question.value()) + "</textarea>";
            case "select":
              return "                <select name='" + name + "'>" + (_.map(question.get("select-options").split(/, */), function(option) {
                return "<option>" + option + "</option>";
              }).join("")) + "                </select>              ";
            case "radio":
              return _.map(question.get("radio-options").split(/, */), function(option, index) {
                return "                  <label for='" + question_id + "-" + index + "'>" + option + "</label>                  <input type='radio' name='" + name + "' id='" + question_id + "-" + index + "' value='" + option + "'/>                ";
              }).join("");
            case "checkbox":
              return "<input style='display:none' name='" + name + "' id='" + question_id + "' type='checkbox' value='true'></input>";
            case "autocomplete from list":
              return "<input name='" + name + "' id='" + question_id + "' type='" + (question.type()) + "' value='" + (question.value()) + "' data-autocomplete-options='" + (question.get("autocomplete-options")) + "'></input>";
            case "autocomplete from previous entries":
              return "<input name='" + name + "' id='" + question_id + "' type='" + (question.type()) + "' value='" + (question.value()) + "'></input>";
            default:
              return "<input name='" + name + "' id='" + question_id + "' type='" + (question.type()) + "' value='" + (question.value()) + "'></input>";
          }
        })();
        result += "          </div>        ";
        return result + repeatable;
      } else {
        newGroupId = question_id;
        if (question.repeatable()) newGroupId = newGroupId + "[0]";
        return ("<div data-group-id='" + question_id + "' class='question group'>") + _this.toHTMLForm(question.questions(), newGroupId) + "</div>" + repeatable;
      }
    }).join("");
  };

  return QuestionView;

})(Backbone.View);
