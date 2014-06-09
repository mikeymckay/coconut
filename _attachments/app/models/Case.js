var Case,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Case = (function() {
  function Case(options) {
    this.fetchResults = __bind(this.fetchResults, this);
    this.resultsAsArray = __bind(this.resultsAsArray, this);
    this.daysFromNotificationToCompletion = __bind(this.daysFromNotificationToCompletion, this);
    this.followedUp = __bind(this.followedUp, this);
    this.complete = __bind(this.complete, this);
    this.questionStatus = __bind(this.questionStatus, this);
    this.toJSON = __bind(this.toJSON, this);
    this.caseID = options != null ? options.caseID : void 0;
    if (options != null ? options.results : void 0) {
      this.loadFromResultDocs(options.results);
    }
  }

  Case.prototype.loadFromResultDocs = function(resultDocs) {
    var userRequiresDeidentification, _ref, _ref1;
    this.caseResults = resultDocs;
    this.questions = [];
    this["Household Members"] = [];
    userRequiresDeidentification = (((_ref = User.currentUser) != null ? _ref.hasRole("reports") : void 0) || User.currentUser === null) && !((_ref1 = User.currentUser) != null ? _ref1.hasRole("admin") : void 0);
    return _.each(resultDocs, (function(_this) {
      return function(resultDoc) {
        if (resultDoc.toJSON != null) {
          resultDoc = resultDoc.toJSON();
        }
        if (userRequiresDeidentification) {
          _.each(resultDoc, function(value, key) {
            if ((value != null) && _.contains(Coconut.identifyingAttributes, key)) {
              return resultDoc[key] = b64_sha1(value);
            }
          });
        }
        if (resultDoc.question) {
          if (_this.caseID == null) {
            _this.caseID = resultDoc["MalariaCaseID"];
          }
          if (_this.caseID !== resultDoc["MalariaCaseID"]) {
            throw "Inconsistent Case ID";
          }
          _this.questions.push(resultDoc.question);
          if (resultDoc.question === "Household Members") {
            return _this["Household Members"].push(resultDoc);
          } else {
            if (_this[resultDoc.question] != null) {
              if (_this[resultDoc.question].complete === "true" && (resultDoc.complete !== "true")) {
                console.log("Using the result marked as complete");
                return;
              } else if (_this[resultDoc.question].complete && resultDoc.complete) {
                console.error("Duplicate complete entries for case: " + _this.caseID);
              }
            }
            return _this[resultDoc.question] = resultDoc;
          }
        } else {
          if (_this.caseID == null) {
            _this.caseID = resultDoc["caseid"];
          }
          if (_this.caseID !== resultDoc["caseid"]) {
            console.log(resultDoc);
            console.log(resultDocs);
            throw "Inconsistent Case ID. Working on " + _this.caseID + " but current doc has " + resultDoc["caseid"];
          }
          _this.questions.push("USSD Notification");
          return _this["USSD Notification"] = resultDoc;
        }
      };
    })(this));
  };

  Case.prototype.fetch = function(options) {
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/cases", {
      key: this.caseID,
      include_docs: true,
      success: (function(_this) {
        return function(result) {
          _this.loadFromResultDocs(_.pluck(result.rows, "doc"));
          return options != null ? options.success() : void 0;
        };
      })(this),
      error: (function(_this) {
        return function() {
          return options != null ? options.error() : void 0;
        };
      })(this)
    });
  };

  Case.prototype.toJSON = function() {
    var returnVal;
    returnVal = {};
    _.each(this.questions, (function(_this) {
      return function(question) {
        return returnVal[question] = _this[question];
      };
    })(this));
    return returnVal;
  };

  Case.prototype.deIdentify = function(result) {};

  Case.prototype.flatten = function(questions) {
    var returnVal;
    if (questions == null) {
      questions = this.questions;
    }
    returnVal = {};
    _.each(questions, (function(_this) {
      return function(question) {
        var type;
        type = question;
        return _.each(_this[question], function(value, field) {
          if (_.isObject(value)) {
            return _.each(value, function(arrayValue, arrayField) {
              return returnVal["" + question + "-" + field + ": " + arrayField] = arrayValue;
            });
          } else {
            return returnVal["" + question + ":" + field] = value;
          }
        });
      };
    })(this));
    return returnVal;
  };

  Case.prototype.LastModifiedAt = function() {
    return _.chain(this.toJSON()).map(function(question) {
      return question.lastModifiedAt;
    }).max(function(lastModifiedAt) {
      return lastModifiedAt != null ? lastModifiedAt.replace(/[- :]/g, "") : void 0;
    }).value();
  };

  Case.prototype.Questions = function() {
    return _.keys(this.toJSON()).join(", ");
  };

  Case.prototype.MalariaCaseID = function() {
    return this.caseID;
  };

  Case.prototype.facility = function() {
    var _ref, _ref1;
    return ((_ref = this["USSD Notification"]) != null ? _ref.hf : void 0) || ((_ref1 = this["Case Notification"]) != null ? _ref1.FacilityName : void 0);
  };

  Case.prototype.validShehia = function() {
    var _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    if (((_ref = this.Household) != null ? _ref.Shehia : void 0) && GeoHierarchy.findOneShehia(this.Household.Shehia)) {
      return (_ref1 = this.Household) != null ? _ref1.Shehia : void 0;
    } else if (((_ref2 = this.Facility) != null ? _ref2.Shehia : void 0) && GeoHierarchy.findOneShehia(this.Facility.Shehia)) {
      return (_ref3 = this.Facility) != null ? _ref3.Shehia : void 0;
    } else if (((_ref4 = this["Case Notification"]) != null ? _ref4.Shehia : void 0) && GeoHierarchy.findOneShehia((_ref5 = this["Case Notification"]) != null ? _ref5.Shehia : void 0)) {
      return (_ref6 = this["Case Notification"]) != null ? _ref6.Shehia : void 0;
    } else if (((_ref7 = this["USSD Notification"]) != null ? _ref7.shehia : void 0) && GeoHierarchy.findOneShehia((_ref8 = this["USSD Notification"]) != null ? _ref8.shehia : void 0)) {
      return (_ref9 = this["USSD Notification"]) != null ? _ref9.shehia : void 0;
    }
    return null;
  };

  Case.prototype.shehia = function() {
    var returnVal, _ref, _ref1, _ref2;
    returnVal = this.validShehia();
    if (returnVal != null) {
      return returnVal;
    }
    console.warn("No valid shehia found for case: " + (this.MalariaCaseID()) + " result will be either null or unknown");
    return ((_ref = this.Household) != null ? _ref.Shehia : void 0) || ((_ref1 = this.Facility) != null ? _ref1.Shehia : void 0) || ((_ref2 = this["USSD Notification"]) != null ? _ref2.shehia : void 0);
  };

  Case.prototype.user = function() {
    var userId, _ref, _ref1, _ref2;
    return userId = ((_ref = this.Household) != null ? _ref.user : void 0) || ((_ref1 = this.Facility) != null ? _ref1.user : void 0) || ((_ref2 = this["Case Notification"]) != null ? _ref2.user : void 0);
  };

  Case.prototype.district = function() {
    var district, shehia, _ref, _ref1, _ref2;
    shehia = this.validShehia();
    if (shehia != null) {
      return GeoHierarchy.findOneShehia(shehia).DISTRICT;
    } else {
      console.warn("" + (this.MalariaCaseID()) + ": No valid shehia found, using district of reporting health facility (which may not be where the patient lives)");
      district = GeoHierarchy.swahiliDistrictName((_ref = this["USSD Notification"]) != null ? _ref.facility_district : void 0);
      if (_(GeoHierarchy.allDistricts()).include(district)) {
        return district;
      } else {
        console.warn("" + (this.MalariaCaseID()) + ": The reported district (" + district + ") used for the reporting facility is not a valid district. Looking up the district for the health facility name.");
        district = GeoHierarchy.swahiliDistrictName(FacilityHierarchy.getDistrict((_ref1 = this["USSD Notification"]) != null ? _ref1.hf : void 0));
        if (_(GeoHierarchy.allDistricts()).include(district)) {
          return district;
        } else {
          console.warn("" + (this.MalariaCaseID()) + ": The health facility name (" + ((_ref2 = this["USSD Notification"]) != null ? _ref2.hf : void 0) + ") is not valid. Giving up and returning UNKNOWN.");
          return "UNKNOWN";
        }
      }
    }
  };

  Case.prototype.possibleQuestions = function() {
    return ["Case Notification", "Facility", "Household", "Household Members"];
  };

  Case.prototype.questionStatus = function() {
    var result;
    result = {};
    _.each(this.possibleQuestions(), (function(_this) {
      return function(question) {
        var _ref;
        if (question === "Household Members") {
          result["Household Members"] = true;
          return _.each(_this["Household Members"] != null, function(member) {
            if (member.complete === "false") {
              return result["Household Members"] = false;
            }
          });
        } else {
          return result[question] = ((_ref = _this[question]) != null ? _ref.complete : void 0) === "true";
        }
      };
    })(this));
    return result;
  };

  Case.prototype.complete = function() {
    return this.questionStatus()["Household Members"] === true;
  };

  Case.prototype.followedUp = function() {
    var _ref, _ref1;
    return ((_ref = this.Household) != null ? _ref.complete : void 0) === "true" || ((_ref1 = this.Facility) != null ? _ref1.Hassomeonefromthesamehouseholdrecentlytestedpositiveatahealthfacility : void 0) === "Yes";
  };

  Case.prototype.daysFromNotificationToCompletion = function() {
    var completionTime, startTime;
    startTime = moment(this["Case Notification"].lastModifiedAt);
    completionTime = null;
    _.each(this["Household Members"], function(member) {
      if (moment(member.lastModifiedAt) > completionTime) {
        return completionTime = moment(member.lastModifiedAt);
      }
    });
    return completionTime.diff(startTime, "days");
  };

  Case.prototype.location = function(type) {
    var _ref, _ref1;
    return (_ref = GeoHierarchy.findOneShehia((_ref1 = this.toJSON()["Case Notification"]) != null ? _ref1["FacilityName"] : void 0)) != null ? _ref[type.toUpperCase()] : void 0;
  };

  Case.prototype.withinLocation = function(location) {
    return this.location(location.type) === location.name;
  };

  Case.prototype.hasAdditionalPositiveCasesAtHousehold = function() {
    return _.any(this["Household Members"], function(householdMember) {
      return householdMember.MalariaTestResult === "PF" || householdMember.MalariaTestResult === "Mixed";
    });
  };

  Case.prototype.positiveCasesAtHousehold = function() {
    return _.compact(_.map(this["Household Members"], function(householdMember) {
      if (householdMember.MalariaTestResult === "PF" || householdMember.MalariaTestResult === "Mixed") {
        return householdMember;
      }
    }));
  };

  Case.prototype.positiveCasesIncludingIndex = function() {
    if (this["Facility"]) {
      return this.positiveCasesAtHousehold().concat(_.extend(this["Facility"], this["Household"]));
    } else if (this["USSD Notification"]) {
      return this.positiveCasesAtHousehold().concat(_.extend(this["USSD Notification"], this["Household"], {
        MalariaCaseID: this.MalariaCaseID()
      }));
    }
  };

  Case.prototype.indexCasePatientName = function() {
    var _ref, _ref1, _ref2;
    if (((_ref = this["Facility"]) != null ? _ref.complete : void 0) === "true") {
      return "" + this["Facility"].FirstName + " " + this["Facility"].LastName;
    }
    if (this["USSD Notification"] != null) {
      return (_ref1 = this["USSD Notification"]) != null ? _ref1.name : void 0;
    }
    if (this["Case Notification"] != null) {
      return (_ref2 = this["Case Notification"]) != null ? _ref2.Name : void 0;
    }
  };

  Case.prototype.indexCaseDiagnosisDate = function() {
    var date, _ref;
    if (((_ref = this["Facility"]) != null ? _ref.DateofPositiveResults : void 0) != null) {
      date = this["Facility"].DateofPositiveResults;
      if (date.match(/^20\d\d/)) {
        return moment(this["Facility"].DateofPositiveResults).format("YYYY-MM-DD");
      } else {
        return moment(this["Facility"].DateofPositiveResults, "DD-MM-YYYY").format("YYYY-MM-DD");
      }
    } else if (this["USSD Notification"] != null) {
      return moment(this["USSD Notification"].date).format("YYYY-MM-DD");
    }
  };

  Case.prototype.householdMembersDiagnosisDate = function() {
    var returnVal;
    returnVal = [];
    return _.each(this["Household Members"] != null, function(member) {
      if (member.MalariaTestResult === "PF" || member.MalariaTestResult === "Mixed") {
        return returnVal.push(member.lastModifiedAt);
      }
    });
  };

  Case.prototype.resultsAsArray = function() {
    return _.chain(this.possibleQuestions()).map((function(_this) {
      return function(question) {
        return _this[question];
      };
    })(this)).flatten().compact().value();
  };

  Case.prototype.fetchResults = function(options) {
    var count, results;
    results = _.map(this.resultsAsArray(), (function(_this) {
      return function(result) {
        var returnVal;
        returnVal = new Result();
        returnVal.id = result._id;
        return returnVal;
      };
    })(this));
    count = 0;
    _.each(results, function(result) {
      return result.fetch({
        success: function() {
          count += 1;
          if (count >= results.length) {
            return options.success(results);
          }
        }
      });
    });
    return results;
  };

  Case.prototype.updateCaseID = function(newCaseID) {
    return this.fetchResults({
      success: function(results) {
        return _.each(results, function(result) {
          if (result.attributes.MalariaCaseID == null) {
            throw "No MalariaCaseID";
          }
          return result.save({
            MalariaCaseID: newCaseID
          });
        });
      }
    });
  };

  Case.prototype.issuesRequiringCleaning = function() {
    var issues, questionTypes, resultCount, _ref;
    resultCount = {};
    questionTypes = "USSD Notification, Case Notification, Facility, Household, Household Members".split(/, /);
    _.each(questionTypes, function(questionType) {
      return resultCount[questionType] = 0;
    });
    _.each(this.caseResults, function(result) {
      if (result.caseid != null) {
        resultCount["USSD Notification"]++;
      }
      if (result.question != null) {
        return resultCount[result.question]++;
      }
    });
    issues = [];
    _.each(questionTypes.slice(0, 4), function(questionType) {
      if (resultCount[questionType] > 1) {
        return issues.push("" + resultCount[questionType] + " " + questionType + "s");
      }
    });
    if (!this.followedUp()) {
      issues.push("Not followed up");
    }
    if (this.caseResults.length === 1) {
      issues.push("Orphaned result");
    }
    if (!((this["Case Notification"] != null) || ((_ref = this["Case Notification"]) != null ? _ref.length : void 0) === 0)) {
      issues.push("Missing case notification");
    }
    return issues;
  };

  Case.prototype.allResultsByQuestion = function() {
    var returnVal;
    returnVal = {};
    _.each("USSD Notification, Case Notification, Facility, Household".split(/, /), function(question) {
      return returnVal[question] = [];
    });
    _.each(this.caseResults, function(result) {
      if (result["question"] != null) {
        return returnVal[result["question"]].push(result);
      } else if (result.hf != null) {
        return returnVal["USSD Notification"].push(result);
      }
    });
    return returnVal;
  };

  Case.prototype.redundantResults = function() {
    var redundantResults;
    redundantResults = [];
    return _.each(this.allResultsByQuestion, function(results, question) {
      return console.log(_.sort(results, "createdAt"));
    });
  };

  return Case;

})();
