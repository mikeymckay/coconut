var QuestionView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

window.SkipTheseWhen = function(argQuestions, result) {
  var disabledClass, question, questions, _i, _j, _len, _len1, _results;
  questions = [];
  argQuestions = argQuestions.split(/\s*,\s*/);
  for (_i = 0, _len = argQuestions.length; _i < _len; _i++) {
    question = argQuestions[_i];
    questions.push(window.questionCache[question]);
  }
  disabledClass = "disabled_skipped";
  _results = [];
  for (_j = 0, _len1 = questions.length; _j < _len1; _j++) {
    question = questions[_j];
    if (result) {
      _results.push(question.addClass(disabledClass));
    } else {
      _results.push(question.removeClass(disabledClass));
    }
  }
  return _results;
};

window.ResultOfQuestion = function(name) {
  var _base;
  return (typeof (_base = window.getValueCache)[name] === "function" ? _base[name]() : void 0) || null;
};

QuestionView = (function(_super) {
  __extends(QuestionView, _super);

  function QuestionView() {
    this.render = __bind(this.render, this);
    return QuestionView.__super__.constructor.apply(this, arguments);
  }

  QuestionView.prototype.initialize = function() {
    if (Coconut.resultCollection == null) {
      Coconut.resultCollection = new ResultCollection();
    }
    return this.autoscrollTimer = 0;
  };

  QuestionView.prototype.el = '#content';

  QuestionView.prototype.triggerChangeIn = function(names) {
    var elements, name, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = names.length; _i < _len; _i++) {
      name = names[_i];
      elements = [];
      elements.push(window.questionCache[name].find("input, select, textarea, img"));
      _results.push($(elements).each((function(_this) {
        return function(index, element) {
          var event;
          event = {
            target: element
          };
          return _this.actionOnChange(event);
        };
      })(this)));
    }
    return _results;
  };

  QuestionView.prototype.render = function() {
    var autocompleteElements, skipperList;
    this.$el.html("<style> .message { color: grey; font-weight: bold; padding: 10px; border: 1px yellow dotted; background: yellow; display: none; } label.radio { border-radius:20px; display:block; padding:4px 11px; border: 1px solid black; cursor: pointer; text-decoration: none; } input[type='radio']:checked + label { background-color:#ddd; background: #5393c5; background-image: -webkit-gradient(linear,left top,left bottom,from(#5393c5),to(#6facd5)); background-image: -webkit-linear-gradient(#5393c5,#6facd5); background-image: -moz-linear-gradient(#5393c5,#6facd5); background-image: -ms-linear-gradient(#5393c5,#6facd5); background-image: -o-linear-gradient(#5393c5,#6facd5); background-image: linear-gradient(#5393c5,#6facd5); } input[type='radio']{ height: 0px; } div.question.radio{ padding-top: 8px; padding-bottom: 8px; } .tt-hint{ display:none } .tt-dropdown-menu{ width: 100%; background-color: lightgray; } .tt-suggestion{ background-color: white; border-radius:20px; display:block; padding:4px 11px; border: 1px solid black; cursor: pointer; text-decoration: none; } .tt-suggestion .{ } </style> <div style='position:fixed; right:5px; color:white; padding:20px; z-index:5' id='messageText'> <a href='#help/" + this.model.id + "'>Help</a> </div> <div style='position:fixed; right:5px; color:white; background-color: #333; padding:20px; display:none; z-index:10' id='messageText'> Saving... </div> <h1>" + this.model.id + "</h1> <div id='question-view'> <form> " + (this.toHTMLForm(this.model)) + " </form> </div>");
    js2form($('form').get(0), this.result.toJSON());
    this.updateCache();
    this.updateSkipLogic();
    skipperList = [];
    $(this.model.get("questions")).each((function(_this) {
      return function(index, question) {
        if (question.actionOnChange().match(/skip/i)) {
          skipperList.push(question.safeLabel());
        }
        if ((question.get("action_on_questions_loaded") != null) && question.get("action_on_questions_loaded") !== "") {
          return CoffeeScript["eval"](question.get("action_on_questions_loaded"));
        }
      };
    })(this));
    this.triggerChangeIn(skipperList);
    this.$el.find("input[type=text],input[type=number],input[type='autocomplete from previous entries'],input[type='autocomplete from list'],input[type='autocomplete from code']").textinput();
    this.$el.find('input[type=checkbox]').checkboxradio();
    this.$el.find('ul').listview();
    this.$el.find('select').selectmenu();
    this.$el.find('a').button();
    this.$el.find('input[type=date]').datebox({
      mode: "calbox",
      dateFormat: "%d-%m-%Y"
    });
    autocompleteElements = [];
    _.each($("input[type='autocomplete from list']"), function(element) {
      element = $(element);
      element.typeahead({
        local: element.attr("data-autocomplete-options").replace(/\n|\t/, "").split(/, */)
      });
      return autocompleteElements.push(element);
    });
    _.each($("input[type='autocomplete from code']"), function(element) {
      element = $(element);
      element.typeahead({
        local: eval(element.attr("data-autocomplete-options"))
      });
      return autocompleteElements.push(element);
    });
    _.each($("input[type='autocomplete from previous entries']"), function(element) {
      element = $(element);
      element.typeahead({
        prefetch: document.location.pathname.substring(0, document.location.pathname.indexOf("index.html")) + ("_list/values/byValue?key=\"" + (element.attr("name")) + "\"")
      });
      return autocompleteElements.push(element);
    });
    _.each(autocompleteElements, (function(_this) {
      return function(autocompeteElement) {
        return autocompeteElement.blur(function() {
          return _this.autoscroll(autocompeteElement);
        });
      };
    })(this));
    if (this.readonly) {
      return $('input, textarea').attr("readonly", "true");
    }
  };

  QuestionView.prototype.events = {
    "change #question-view input": "onChange",
    "change #question-view select": "onChange",
    "change #question-view textarea": "onChange",
    "click #question-view button:contains(+)": "repeat",
    "click #question-view a:contains(Get current location)": "getLocation",
    "click .next_error": "runValidate",
    "click .validate_one": "onValidateOne"
  };

  QuestionView.prototype.runValidate = function() {
    return this.validateAll();
  };

  QuestionView.prototype.onChange = function(event) {
    var $target, eventStamp, messageVisible, targetName;
    $target = $(event.target);
    eventStamp = $target.attr("id");
    if (eventStamp === this.oldStamp && (new Date()).getTime() < this.throttleTime + 1000) {
      return;
    }
    this.throttleTime = (new Date()).getTime();
    this.oldStamp = eventStamp;
    targetName = $target.attr("name");
    if (targetName === "complete") {
      if (this.changedComplete) {
        this.changedComplete = false;
        return;
      }
      this.validateAll();
      Coconut.menuView.update();
      this.save();
      this.updateSkipLogic();
      return this.actionOnChange(event);
    } else {
      this.changedComplete = false;
      messageVisible = window.questionCache[targetName].find(".message").is(":visible");
      return _.delay((function(_this) {
        return function() {
          var wasValid;
          if (!messageVisible) {
            wasValid = _this.validateOne({
              key: targetName,
              autoscroll: false,
              button: "<button type='button' data-name='" + targetName + "' class='validate_one'>Validate</button>"
            });
            _this.save();
            _this.updateSkipLogic();
            _this.actionOnChange(event);
            if (wasValid) {
              return _this.autoscroll(event);
            }
          }
        };
      })(this), 500);
    }
  };

  QuestionView.prototype.onValidateOne = function(event) {
    var $target, name;
    $target = $(event.target);
    name = $(event.target).attr('data-name');
    return this.validateOne({
      key: name,
      autoscroll: true,
      leaveMessage: false,
      button: "<button type='button' data-name='" + name + "' class='validate_one'>Validate</button>"
    });
  };

  QuestionView.prototype.validateAll = function() {
    var isValid, key, questionIsntValid, _i, _len, _ref;
    isValid = true;
    _ref = window.keyCache;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      key = _ref[_i];
      questionIsntValid = !this.validateOne({
        key: key,
        autoscroll: isValid,
        leaveMessage: false
      });
      if (isValid && questionIsntValid) {
        isValid = false;
      }
    }
    this.completeButton(isValid);
    if (isValid) {
      $("[name=complete]").parent().scrollTo();
    }
    return isValid;
  };

  QuestionView.prototype.validateOne = function(options) {
    var $message, $question, autoscroll, button, e, key, leaveMessage, message;
    key = options.key || '';
    autoscroll = options.autoscroll || false;
    button = options.button || "<button type='button' class='next_error'>Next Error</button>";
    leaveMessage = options.leaveMessage || false;
    $question = window.questionCache[key];
    $message = $question.find(".message");
    try {
      message = this.isValid(key);
    } catch (_error) {
      e = _error;
      alert("isValid error in " + key + "\n" + e);
      message = "";
    }
    if ($message.is(":visible") && leaveMessage) {
      if (message === "") {
        return true;
      } else {
        return false;
      }
    }
    if (message === "") {
      $message.hide();
      if (autoscroll) {
        this.autoscroll($question);
      }
      return true;
    } else {
      $message.show().html("" + message + " " + button).find("button").button();
      this.scrollToQuestion($question);
      return false;
    }
  };

  QuestionView.prototype.isValid = function(question_id) {
    var error, labelText, question, questionWrapper, required, result, type, validation, validationFunctionResult, value, _ref;
    if (!question_id) {
      return;
    }
    result = [];
    questionWrapper = window.questionCache[question_id];
    if (questionWrapper.hasClass("label")) {
      return "";
    }
    question = $("[name=" + question_id + "]", questionWrapper);
    type = $(questionWrapper.find("input").get(0)).attr("type");
    labelText = type === "radio" ? $("label[for=" + (question.attr("id").split("-")[0]) + "]", questionWrapper).text() || "" : (_ref = $("label[for=" + (question.attr("id")) + "]", questionWrapper)) != null ? _ref.text() : void 0;
    required = questionWrapper.attr("data-required") === "true";
    validation = unescape(questionWrapper.attr("data-validation"));
    if (validation === "undefined") {
      validation = null;
    }
    value = window.getValueCache[question_id]();
    if (!questionWrapper.is(":visible")) {
      return "";
    }
    if (question.find("input").length !== 0 && (type === "checkbox" || type === "radio")) {
      return "";
    }
    if (required && (value === "" || value === null)) {
      result.push("'" + labelText + "' is required.");
    }
    if ((validation != null) && validation !== "") {
      try {
        validationFunctionResult = (CoffeeScript["eval"]("(value) -> " + validation, {
          bare: true
        }))(value);
        if (validationFunctionResult != null) {
          result.push(validationFunctionResult);
        }
      } catch (_error) {
        error = _error;
        if (error === 'invisible reference') {
          return '';
        }
        alert("Validation error for " + question_id + " with value " + value + ": " + error);
      }
    }
    if (result.length !== 0) {
      return result.join("<br>") + "<br>";
    }
    return "";
  };

  QuestionView.prototype.scrollToQuestion = function(question) {
    return this.autoscroll($(question).prev());
  };

  QuestionView.prototype.autoscroll = function(event) {
    var $div, $target, safetyCounter;
    clearTimeout(this.autoscrollTimer);
    if (event.jquery) {
      $div = event;
      window.scrollTargetName = $div.attr("data-question-name") || $div.attr("name");
    } else {
      $target = $(event.target);
      window.scrollTargetName = $target.attr("name");
      $div = window.questionCache[window.scrollTargetName];
    }
    this.$next = $div.next();
    if (!this.$next.is(":visible") && this.$next.length > 0) {
      safetyCounter = 0;
      while (!this.$next.is(":visible") && (safetyCounter += 1) < 100) {
        this.$next = this.$next.next();
      }
    }
    if (this.$next.is(":visible")) {
      if (window.questionCache[window.scrollTargetName].find(".message").is(":visible")) {
        return;
      }
      $(window).on("scroll", (function(_this) {
        return function() {
          $(window).off("scroll");
          return clearTimeout(_this.autoscrollTimer);
        };
      })(this));
      return this.autoscrollTimer = setTimeout((function(_this) {
        return function() {
          $(window).off("scroll");
          return _this.$next.scrollTo().find("input[type=text],input[type=number]").focus();
        };
      })(this), 1000);
    }
  };

  QuestionView.prototype.actionOnChange = function(event) {
    var $divQuestion, $target, code, error, message, name, newFunction, nodeName, value;
    nodeName = $(event.target).get(0).nodeName;
    $target = nodeName === "INPUT" || nodeName === "SELECT" || nodeName === "TEXTAREA" ? $(event.target) : $(event.target).parent().parent().parent().find("input,textarea,select");
    if (!$target.is(":visible")) {
      return;
    }
    name = $target.attr("name");
    $divQuestion = $(".question [data-question-name=" + name + "]");
    code = $divQuestion.attr("data-action_on_change");
    try {
      value = ResultOfQuestion(name);
    } catch (_error) {
      error = _error;
      if (error === "invisible reference") {
        return;
      }
    }
    if (code === "" || (code == null)) {
      return;
    }
    code = "(value) -> " + code;
    try {
      newFunction = CoffeeScript["eval"].apply(this, [code]);
      return newFunction(value);
    } catch (_error) {
      error = _error;
      name = (/function (.{1,})\(/.exec(error.constructor.toString())[1]);
      message = error.message;
      return alert("Action on change error in question " + ($divQuestion.attr('data-question-id') || $divQuestion.attr("id")) + "\n\n" + name + "\n\n" + message);
    }
  };

  QuestionView.prototype.updateSkipLogic = function() {
    var $question, error, message, name, result, skipLogicCode, _ref, _results;
    _ref = window.questionCache;
    _results = [];
    for (name in _ref) {
      $question = _ref[name];
      skipLogicCode = window.skipLogicCache[name];
      if (skipLogicCode === "" || (skipLogicCode == null)) {
        continue;
      }
      try {
        result = eval(skipLogicCode);
      } catch (_error) {
        error = _error;
        if (error === "invisible reference") {
          result = true;
        } else {
          name = (/function (.{1,})\(/.exec(error.constructor.toString())[1]);
          message = error.message;
          alert("Skip logic error in question " + ($question.attr('data-question-id')) + "\n\n" + name + "\n\n" + message);
        }
      }
      if (result) {
        _results.push($question[0].style.display = "none");
      } else {
        _results.push($question[0].style.display = "");
      }
    }
    return _results;
  };

  QuestionView.prototype.save = _.throttle(function() {
    var currentData;
    currentData = $('form').toObject({
      skipEmpty: false
    });
    currentData.lastModifiedAt = moment(new Date()).format(Coconut.config.get("datetime_format"));
    currentData.savedBy = $.cookie('current_user');
    return this.result.save(currentData, {
      success: (function(_this) {
        return function(model) {
          var malariaCase;
          $("#messageText").slideDown().fadeOut();
          Coconut.router.navigate("edit/result/" + model.id, false);
          Coconut.menuView.update();
          if (_this.result.complete()) {
            if (_this.result.nextLevelCreated !== true) {
              _this.result.nextLevelCreated = true;
              malariaCase = new Case({
                caseID: _this.result.get("MalariaCaseID")
              });
              return malariaCase.fetch({
                error: function(error) {
                  return console.log(error);
                },
                success: function() {
                  var result;
                  switch (_this.result.get('question')) {
                    case "Case Notification":
                      if (!_(malariaCase.questions).contains('Facility')) {
                        result = new Result({
                          question: "Facility",
                          MalariaCaseID: _this.result.get("MalariaCaseID"),
                          FacilityName: _this.result.get("FacilityName"),
                          Shehia: _this.result.get("Shehia")
                        });
                        return result.save(null, {
                          success: function() {
                            return Coconut.menuView.update();
                          }
                        });
                      }
                      break;
                    case "Facility":
                      if (!_(malariaCase.questions).contains('Household')) {
                        result = new Result({
                          question: "Household",
                          MalariaCaseID: _this.result.get("MalariaCaseID"),
                          HeadofHouseholdName: _this.result.get("HeadofHouseholdName"),
                          Shehia: _this.result.get("Shehia"),
                          Village: _this.result.get("Village"),
                          ShehaMjumbe: _this.result.get("ShehaMjumbe"),
                          ContactMobilepatientrelative: _this.result.get("ContactMobilepatientrelative")
                        });
                        return result.save(null, {
                          success: function() {
                            return Coconut.menuView.update();
                          }
                        });
                      }
                      break;
                    case "Household":
                      if (!_(malariaCase.questions).contains('Household Members')) {
                        return _(_this.result.get("TotalNumberofResidentsintheHousehold") - 1).times(function() {
                          result = new Result({
                            question: "Household Members",
                            MalariaCaseID: _this.result.get("MalariaCaseID"),
                            HeadofHouseholdName: _this.result.get("HeadofHouseholdName")
                          });
                          return result.save(null, {
                            success: function() {
                              return Coconut.menuView.update();
                            }
                          });
                        });
                      }

                      /*
                        TODO need to update Case to handle arrays of Households
                        Two options:
                        1) Add new questions: HouseholdNeighbor - > breaks question paradigm
                        2) Change Household to be an array - > breaks reports
                      unless _(malariaCase.questions).contains 'Household'
                        _(@result.get("Numberofotherhouseholdswithin50stepsofindexcasehousehold")).times =>
                          result = new Result
                            question: "Household"
                            MalariaCaseID: @result.get "MalariaCaseID"
                            Shehia: @result.get "Shehia"
                            Village: @result.get "Village"
                            ShehaMjumbe: @result.get "ShehaMjumbe"
                          result.save null,
                            success: ->
                              Coconut.menuView.update()
                       */
                  }
                }
              });
            }
          }
        };
      })(this)
    });
  }, 1000);

  QuestionView.prototype.completeButton = function(value) {
    this.changedComplete = true;
    if ($('[name=complete]').prop("checked") !== value) {
      return $('[name=complete]').click();
    }
  };

  QuestionView.prototype.toHTMLForm = function(questions, groupId) {
    if (questions == null) {
      questions = this.model;
    }
    window.skipLogicCache = {};
    if (questions.length == null) {
      questions = [questions];
    }
    return _.map(questions, (function(_this) {
      return function(question) {
        var html, index, name, newGroupId, option, options, question_id, repeatable;
        if (question.repeatable() === "true") {
          repeatable = "<button>+</button>";
        } else {
          repeatable = "";
        }
        if ((question.type() != null) && (question.label() != null) && question.label() !== "") {
          name = question.safeLabel();
          window.skipLogicCache[name] = question.skipLogic() !== '' ? CoffeeScript.compile(question.skipLogic(), {
            bare: true
          }) : '';
          question_id = question.get("id");
          if (question.repeatable() === "true") {
            name = name + "[0]";
            question_id = question.get("id") + "-0";
          }
          if (groupId != null) {
            name = "group." + groupId + "." + name;
          }
          return "<div " + (question.validation() ? question.validation() ? "data-validation = '" + (escape(question.validation())) + "'" : void 0 : "") + " data-required='" + (question.required()) + "' class='question " + ((typeof question.type === "function" ? question.type() : void 0) || '') + "' data-question-name='" + name + "' data-question-id='" + question_id + "' data-action_on_change='" + (_.escape(question.actionOnChange())) + "' > " + (!~question.type().indexOf('hidden') ? "<label type='" + (question.type()) + "' for='" + question_id + "'>" + (question.label()) + " <span></span></label>" : void 0) + " <div class='message'></div> " + ((function() {
            var _i, _len, _ref;
            switch (question.type()) {
              case "textarea":
                return "<input name='" + name + "' type='text' id='" + question_id + "' value='" + (_.escape(question.value())) + "'></input>";
              case "select":
                if (this.readonly) {
                  return question.value();
                } else {
                  html = "<select>";
                  _ref = question.get("select-options").split(/, */);
                  for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
                    option = _ref[index];
                    html += "<option name='" + name + "' id='" + question_id + "-" + index + "' value='" + option + "'>" + option + "</option>";
                  }
                  return html += "</select>";
                }
                break;
              case "radio":
                if (this.readonly) {
                  return "<input class='radioradio' name='" + name + "' type='text' id='" + question_id + "' value='" + (question.value()) + "'></input>";
                } else {
                  options = question.get("radio-options");
                  return _.map(options.split(/, */), function(option, index) {
                    return "<input class='radio' type='radio' name='" + name + "' id='" + question_id + "-" + index + "' value='" + (_.escape(option)) + "'/> <label class='radio' for='" + question_id + "-" + index + "'>" + option + "</label> <!-- <div class='ui-radio'> <label for=''" + question_id + "-" + index + "' data-corners='true' data-shadow='false' data-iconshadow='true' data-wrapperels='span' data-icon='radio-off' data-theme='c' class='ui-btn ui-btn-corner-all ui-btn-icon-left ui-radio-off ui-btn-up-c'> <span class='ui-btn-inner ui-btn-corner-all'> <span class='ui-btn-text'>" + option + "</span> <span class='ui-icon ui-icon-radio-off ui-icon-shadow'>&nbsp;</span> </span> </label> <input type='radio' name='" + name + "' id='" + question_id + "-" + index + "' value='" + (_.escape(option)) + "'/> </div> -->";
                  }).join("");
                }
                break;
              case "checkbox":
                if (this.readonly) {
                  return "<input name='" + name + "' type='text' id='" + question_id + "' value='" + (_.escape(question.value())) + "'></input>";
                } else {
                  return "<input style='display:none' name='" + name + "' id='" + question_id + "' type='checkbox' value='true'></input>";
                }
                break;
              case "autocomplete from list":
              case "autocomplete from previous entries":
              case "autocomplete from code":
                return "<!-- autocomplete='off' disables browser completion --> <input autocomplete='off' name='" + name + "' id='" + question_id + "' type='" + (question.type()) + "' value='" + (question.value()) + "' data-autocomplete-options='" + (question.get("autocomplete-options")) + "'></input> <ul id='" + question_id + "-suggestions' data-role='listview' data-inset='true'/>";
              case "location":
                return "<a data-question-id='" + question_id + "'>Get current location</a> <label for='" + question_id + "-description'>Location Description</label> <input type='text' name='" + name + "-description' id='" + question_id + "-description'></input> " + (_.map(["latitude", "longitude", "accuracy"], function(field) {
                  return "<label for='" + question_id + "-" + field + "'>" + field + "</label><input readonly='readonly' type='number' name='" + name + "-" + field + "' id='" + question_id + "-" + field + "'></input>";
                }).join("")) + " " + (_.map(["altitude", "altitudeAccuracy", "heading", "timestamp"], function(field) {
                  return "<input type='hidden' name='" + name + "-" + field + "' id='" + question_id + "-" + field + "'></input>";
                }).join(""));
              case "image":
                return "<img style='" + (question.get("image-style")) + "' src='" + (question.get("image-path")) + "'/>";
              case "label":
                return "";
              default:
                return "<input name='" + name + "' id='" + question_id + "' type='" + (question.type()) + "' value='" + (question.value()) + "'></input>";
            }
          }).call(_this)) + " </div> " + repeatable;
        } else {
          newGroupId = question_id;
          if (question.repeatable()) {
            newGroupId = newGroupId + "[0]";
          }
          return ("<div data-group-id='" + question_id + "' class='question group'>") + _this.toHTMLForm(question.questions(), newGroupId) + "</div>" + repeatable;
        }
      };
    })(this)).join("");
  };

  QuestionView.prototype.updateCache = function() {
    var $qC, accessorFunction, inputs, name, question, selects, type, _i, _len, _ref;
    window.questionCache = {};
    window.getValueCache = {};
    window.$questions = $(".question");
    _ref = window.$questions;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      question = _ref[_i];
      name = question.getAttribute("data-question-name");
      if ((name != null) && name !== "") {
        accessorFunction = {};
        window.questionCache[name] = $(question);
        $qC = window.questionCache[name];
        selects = $("select[name=" + name + "]", $qC);
        if (selects.length === 0) {
          inputs = $("input[name=" + name + "]", $qC);
          if (inputs.length !== 0) {
            type = inputs[0].getAttribute("type");
            if (type === "radio") {
              (function(name, $qC) {
                return accessorFunction = function() {
                  return $("input:checked", $qC).safeVal();
                };
              })(name, $qC);
            } else if (type === "checkbox") {
              (function(name, $qC) {
                return accessorFunction = function() {
                  return $("input", $qC).map(function() {
                    return $(this).safeVal();
                  });
                };
              })(name, $qC);
            } else {
              (function(inputs) {
                return accessorFunction = function() {
                  return inputs.safeVal();
                };
              })(inputs);
            }
          } else {
            (function(name, $qC) {
              return accessorFunction = function() {
                return $(".textarea[name=" + name + "]", $qC).safeVal();
              };
            })(name, $qC);
          }
        } else {
          (function(selects) {
            return accessorFunction = function() {
              return selects.safeVal();
            };
          })(selects);
        }
        window.getValueCache[name] = accessorFunction;
      }
    }
    return window.keyCache = _.keys(questionCache);
  };

  QuestionView.prototype.repeat = function(event) {
    var button, inputElement, name, newIndex, newQuestion, questionID, re, _i, _len, _ref;
    button = $(event.target);
    newQuestion = button.prev(".question").clone();
    questionID = newQuestion.attr("data-group-id");
    if (questionID == null) {
      questionID = "";
    }
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

  QuestionView.prototype.getLocation = function(event) {
    var question_id;
    question_id = $(event.target).closest("[data-question-id]").attr("data-question-id");
    $("#" + question_id + "-description").val("Retrieving position, please wait.");
    return navigator.geolocation.getCurrentPosition((function(_this) {
      return function(geoposition) {
        _.each(geoposition.coords, function(value, key) {
          return $("#" + question_id + "-" + key).val(value);
        });
        $("#" + question_id + "-timestamp").val(moment(geoposition.timestamp).format(Coconut.config.get("datetime_format")));
        $("#" + question_id + "-description").val("Success");
        _this.save();
        return $.getJSON("http://api.geonames.org/findNearbyPlaceNameJSON?lat=" + geoposition.coords.latitude + "&lng=" + geoposition.coords.longitude + "&username=mikeymckay&callback=?", null, function(result) {
          $("#" + question_id + "-description").val(parseFloat(result.geonames[0].distance).toFixed(1) + " km from center of " + result.geonames[0].name);
          return _this.save();
        });
      };
    })(this), function(error) {
      return $("#" + question_id + "-description").val("Error: " + error);
    }, {
      frequency: 1000,
      enableHighAccuracy: true,
      timeout: 30000,
      maximumAge: 0
    });
  };

  return QuestionView;

})(Backbone.View);

(function($) {
  $.fn.scrollTo = function(speed, callback) {
    var e;
    if (speed == null) {
      speed = 500;
    }
    try {
      $('html, body').animate({
        scrollTop: $(this).offset().top + 'px'
      }, speed, null, callback);
    } catch (_error) {
      e = _error;
      console.log("error", e);
      console.log("Scroll error with 'this'", this);
    }
    return this;
  };
  return $.fn.safeVal = function() {
    if (this.is(":visible") || this.parents(".question").filter(function() {
      return !$(this).hasClass("group");
    }).is(":visible")) {
      return $.trim(this.val() || '');
    } else {
      return null;
    }
  };
})($);
