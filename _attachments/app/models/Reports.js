var Reports,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Reports = (function() {
  function Reports() {
    this.casesAggregatedForAnalysis = __bind(this.casesAggregatedForAnalysis, this);
    this.getCases = __bind(this.getCases, this);
  }

  Reports.prototype.positiveCaseLocations = function(options) {
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/positiveCaseLocations", {
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get("date_format")),
      endkey: options.startDate,
      descending: true,
      success: function(result) {
        var currentLocation, currentLocationIndex, distanceInMeters, loc, locIndex, locations, _i, _j, _len, _len1, _ref, _ref1;
        locations = [];
        _ref = result.rows;
        for (currentLocationIndex = _i = 0, _len = _ref.length; _i < _len; currentLocationIndex = ++_i) {
          currentLocation = _ref[currentLocationIndex];
          currentLocation = currentLocation.value;
          locations[currentLocation] = {
            100: [],
            1000: [],
            5000: [],
            10000: []
          };
          _ref1 = result.rows;
          for (locIndex = _j = 0, _len1 = _ref1.length; _j < _len1; locIndex = ++_j) {
            loc = _ref1[locIndex];
            if (locIndex === currentLocationIndex) {
              continue;
            }
            loc = loc.value;
            distanceInMeters = (new LatLon(currentLocation[0], currentLocation[1])).distanceTo(new LatLon(loc[0], loc[1])) * 1000;
            if (distanceInMeters < 100) {
              locations[currentLocation][100].push(loc);
            } else if (distanceInMeters < 1000) {
              locations[currentLocation][1000].push(loc);
            } else if (distanceInMeters < 5000) {
              locations[currentLocation][5000].push(loc);
            } else if (distanceInMeters < 10000) {
              locations[currentLocation][10000].push(loc);
            }
          }
        }
        return options.success(locations);
      }
    });
  };

  Reports.prototype.positiveCaseClusters = function(options) {
    return this.positiveCaseLocations({
      success: function(positiveCases) {
        var cluster, positiveCase, _results;
        _results = [];
        for (positiveCase in positiveCases) {
          cluster = positiveCases[positiveCase];
          if (cluster[100].length > 4) {
            _results.push(console.log("" + cluster[100].length + " cases within 100 meters of one another"));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      }
    });
  };

  Reports.prototype.getCases = function(options) {
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/caseIDsByDate", {
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get("date_format")),
      endkey: options.startDate,
      descending: true,
      include_docs: false,
      success: (function(_this) {
        return function(result) {
          var caseIDs;
          caseIDs = _.unique(_.pluck(result.rows, "value"));
          return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/cases", {
            keys: caseIDs,
            include_docs: true,
            success: function(result) {
              var groupedResults;
              groupedResults = _.chain(result.rows).groupBy(function(row) {
                return row.key;
              }).map(function(resultsByCaseID) {
                var malariaCase;
                malariaCase = new Case({
                  results: _.pluck(resultsByCaseID, "doc")
                });
                if (options.mostSpecificLocation.name === "ALL" || malariaCase.withinLocation(options.mostSpecificLocation)) {
                  return malariaCase;
                }
              }).compact().value();
              return options.success(groupedResults);
            },
            error: function() {
              return options != null ? options.error() : void 0;
            }
          });
        };
      })(this)
    });
  };

  Reports.prototype.casesAggregatedForAnalysis = function(options) {
    var data;
    data = {};
    options.aggregationLevel || (options.aggregationLevel = "DISTRICT");
    options.finished = options.success;
    return this.getCases(_.extend(options, {
      success: (function(_this) {
        return function(cases) {
          var IRSThresholdInMonths, aggregationNames;
          IRSThresholdInMonths = 6;
          data.followups = {};
          data.passiveCases = {};
          data.ages = {};
          data.gender = {};
          data.netsAndIRS = {};
          data.travel = {};
          data.totalPositiveCases = {};
          aggregationNames = GeoHierarchy.all(options.aggregationLevel);
          aggregationNames.push("UNKNOWN");
          aggregationNames.push("ALL");
          _.each(aggregationNames, function(aggregationName) {
            data.followups[aggregationName] = {
              allCases: [],
              casesWithCompleteFacilityVisit: [],
              casesWithoutCompleteFacilityVisit: [],
              casesWithCompleteHouseholdVisit: [],
              casesWithoutCompleteHouseholdVisit: [],
              missingUssdNotification: [],
              missingCaseNotification: []
            };
            data.passiveCases[aggregationName] = {
              indexCases: [],
              householdMembers: [],
              passiveCases: []
            };
            data.ages[aggregationName] = {
              underFive: [],
              fiveToFifteen: [],
              fifteenToTwentyFive: [],
              overTwentyFive: [],
              unknown: []
            };
            data.gender[aggregationName] = {
              male: [],
              female: [],
              unknown: []
            };
            data.netsAndIRS[aggregationName] = {
              sleptUnderNet: [],
              recentIRS: []
            };
            data.travel[aggregationName] = {
              travelReported: []
            };
            return data.totalPositiveCases[aggregationName] = [];
          });
          _.each(cases, function(malariaCase) {
            var caseLocation, completedHouseholdMembers, positiveCasesAtHousehold, _ref, _ref1, _ref2;
            caseLocation = malariaCase.locationBy(options.aggregationLevel) || "UNKNOWN";
            data.followups[caseLocation].allCases.push(malariaCase);
            data.followups["ALL"].allCases.push(malariaCase);
            if (((_ref = malariaCase["Facility"]) != null ? _ref.complete : void 0) === "true") {
              data.followups[caseLocation].casesWithCompleteFacilityVisit.push(malariaCase);
              data.followups["ALL"].casesWithCompleteFacilityVisit.push(malariaCase);
            } else {
              data.followups[caseLocation].casesWithoutCompleteFacilityVisit.push(malariaCase);
              data.followups["ALL"].casesWithoutCompleteFacilityVisit.push(malariaCase);
            }
            if (((_ref1 = malariaCase["Household"]) != null ? _ref1.complete : void 0) === "true") {
              data.followups[caseLocation].casesWithCompleteHouseholdVisit.push(malariaCase);
              data.followups["ALL"].casesWithCompleteHouseholdVisit.push(malariaCase);
            } else {
              data.followups[caseLocation].casesWithoutCompleteHouseholdVisit.push(malariaCase);
              data.followups["ALL"].casesWithoutCompleteHouseholdVisit.push(malariaCase);
            }
            if (malariaCase["USSD Notification"] == null) {
              data.followups[caseLocation].missingUssdNotification.push(malariaCase);
              data.followups["ALL"].missingUssdNotification.push(malariaCase);
            }
            if (malariaCase["Case Notification"] == null) {
              data.followups[caseLocation].missingCaseNotification.push(malariaCase);
              data.followups["ALL"].missingCaseNotification.push(malariaCase);
            }
            if (((_ref2 = malariaCase["Household"]) != null ? _ref2.complete : void 0) === "true") {
              data.passiveCases[caseLocation].indexCases.push(malariaCase);
              data.passiveCases["ALL"].indexCases.push(malariaCase);
              if (malariaCase["Household Members"] != null) {
                completedHouseholdMembers = _.where(malariaCase["Household Members"], {
                  complete: "true"
                });
                data.passiveCases[caseLocation].householdMembers = data.passiveCases[caseLocation].householdMembers.concat(completedHouseholdMembers);
                data.passiveCases["ALL"].householdMembers = data.passiveCases["ALL"].householdMembers.concat(completedHouseholdMembers);
              }
              positiveCasesAtHousehold = malariaCase.positiveCasesAtHousehold();
              data.passiveCases[caseLocation].passiveCases = data.passiveCases[caseLocation].passiveCases.concat(positiveCasesAtHousehold);
              data.passiveCases["ALL"].passiveCases = data.passiveCases["ALL"].passiveCases.concat(positiveCasesAtHousehold);
              return _.each(malariaCase.positiveCasesIncludingIndex(), function(positiveCase) {
                var age, _ref3, _ref4;
                data.totalPositiveCases[caseLocation].push(positiveCase);
                data.totalPositiveCases["ALL"].push(positiveCase);
                if (positiveCase.Age != null) {
                  age = parseInt(positiveCase.Age);
                  if (age < 5) {
                    data.ages[caseLocation].underFive.push(positiveCase);
                    data.ages["ALL"].underFive.push(positiveCase);
                  } else if (age < 15) {
                    data.ages[caseLocation].fiveToFifteen.push(positiveCase);
                    data.ages["ALL"].fiveToFifteen.push(positiveCase);
                  } else if (age < 25) {
                    data.ages[caseLocation].fifteenToTwentyFive.push(positiveCase);
                    data.ages["ALL"].fifteenToTwentyFive.push(positiveCase);
                  } else if (age >= 25) {
                    data.ages[caseLocation].overTwentyFive.push(positiveCase);
                    data.ages["ALL"].overTwentyFive.push(positiveCase);
                  }
                } else {
                  if (!positiveCase.age) {
                    data.ages[caseLocation].unknown.push(positiveCase);
                  }
                  if (!positiveCase.age) {
                    data.ages["ALL"].unknown.push(positiveCase);
                  }
                }
                if (positiveCase.Sex === "Male") {
                  data.gender[caseLocation].male.push(positiveCase);
                  data.gender["ALL"].male.push(positiveCase);
                } else if (positiveCase.Sex === "Female") {
                  data.gender[caseLocation].female.push(positiveCase);
                  data.gender["ALL"].female.push(positiveCase);
                } else {
                  data.gender[caseLocation].unknown.push(positiveCase);
                  data.gender["ALL"].unknown.push(positiveCase);
                }
                if (positiveCase.SleptunderLLINlastnight === "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight === "Yes") {
                  data.netsAndIRS[caseLocation].sleptUnderNet.push(positiveCase);
                  data.netsAndIRS["ALL"].sleptUnderNet.push(positiveCase);
                }
                if (positiveCase.LastdateofIRS && positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/)) {
                  if ((new moment).subtract('months', Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))) {
                    data.netsAndIRS[caseLocation].recentIRS.push(positiveCase);
                    data.netsAndIRS["ALL"].recentIRS.push(positiveCase);
                  }
                }
                if (((_ref3 = positiveCase.TravelledOvernightinpastmonth) != null ? _ref3.match(/yes/i) : void 0) || ((_ref4 = positiveCase.OvernightTravelinpastmonth) != null ? _ref4.match(/yes/i) : void 0)) {
                  data.travel[caseLocation].travelReported.push(positiveCase);
                  return data.travel["ALL"].travelReported.push(positiveCase);
                }
              });
            }
          });
          return options.finished(data);
        };
      })(this)
    }));
  };

  Reports.systemErrors = function(options) {
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/errorsByDate", {
      startkey: (options != null ? options.endDate : void 0) || moment().format("YYYY-MM-DD"),
      endkey: (options != null ? options.startDate : void 0) || moment().subtract('days', 1).format("YYYY-MM-DD"),
      descending: true,
      include_docs: true,
      success: function(result) {
        var errorsByType;
        errorsByType = {};
        _.chain(result.rows).pluck("doc").each(function(error) {
          if (errorsByType[error.message] != null) {
            errorsByType[error.message].count++;
          } else {
            errorsByType[error.message] = {};
            errorsByType[error.message].count = 0;
            errorsByType[error.message]["Most Recent"] = error.datetime;
            errorsByType[error.message]["Source"] = error.source;
          }
          if (errorsByType[error.message]["Most Recent"] < error.datetime) {
            return errorsByType[error.message]["Most Recent"] = error.datetime;
          }
        });
        return options.success(errorsByType);
      }
    });
  };

  Reports.casesWithoutCompleteHouseholdVisit = function(options) {
    var reports;
    reports = new Reports();
    return reports.casesAggregatedForAnalysis({
      startDate: (options != null ? options.startDate : void 0) || moment().subtract('days', 9).format("YYYY-MM-DD"),
      endDate: (options != null ? options.endDate : void 0) || moment().subtract('days', 2).format("YYYY-MM-DD"),
      mostSpecificLocation: options.mostSpecificLocation,
      success: function(cases) {
        var _ref;
        return options.success((_ref = cases.followups["ALL"]) != null ? _ref.casesWithoutCompleteHouseholdVisit : void 0);
      }
    });
  };

  Reports.unknownDistricts = function(options) {
    var reports;
    reports = new Reports();
    return reports.casesAggregatedForAnalysis({
      startDate: (options != null ? options.startDate : void 0) || moment().subtract('days', 14).format("YYYY-MM-DD"),
      endDate: (options != null ? options.endDate : void 0) || moment().subtract('days', 7).format("YYYY-MM-DD"),
      mostSpecificLocation: options.mostSpecificLocation,
      success: function(cases) {
        var _ref;
        return options.success((_ref = cases.followups["UNKNOWN"]) != null ? _ref.casesWithoutCompleteHouseholdVisit : void 0);
      }
    });
  };

  Reports.userAnalysisTest = function() {
    return this.userAnalysis({
      startDate: "2014-10-01",
      endDate: "2014-12-01",
      success: function(result) {
        return console.log(result);
      }
    });
  };

  Reports.userAnalysis = function(options) {
    return this.userAnalysisForUsers({
      usernames: Users.map(function(user) {
        return user.username();
      }),
      success: options.success,
      startDate: options.startDate,
      endDate: options.endDate
    });
  };

  Reports.userAnalysisForUsers = function(options) {
    var averageTime, averageTimeFormatted, dataByUser, medianTime, medianTimeFormatted, total, usernames;
    usernames = options.usernames;
    medianTime = (function(_this) {
      return function(values) {
        var half;
        values = _(values).filter(function(value) {
          return value >= 0;
        });
        values = _(values).compact();
        values = values.sort(function(a, b) {
          return b - a;
        });
        half = Math.floor(values.length / 2);
        if (values.length % 2) {
          return values[half];
        } else {
          return (values[half - 1] + values[half]) / 2.0;
        }
      };
    })(this);
    medianTimeFormatted = function(times) {
      var duration;
      duration = moment.duration(medianTime(times));
      if (duration.seconds() === 0) {
        return "-";
      } else {
        return duration.humanize();
      }
    };
    averageTime = function(times) {
      var amount, sum;
      sum = 0;
      amount = 0;
      _(times).each(function(time) {
        if (time != null) {
          amount += 1;
          return sum += time;
        }
      });
      if (amount === 0) {
        return 0;
      }
      return sum / amount;
    };
    averageTimeFormatted = function(times) {
      var duration;
      duration = moment.duration(averageTime(times));
      if (duration.seconds() === 0) {
        return "-";
      } else {
        return duration.humanize();
      }
    };
    dataByUser = {};
    _(usernames).each(function(username) {
      return dataByUser[username] = {
        userId: username,
        caseIds: {},
        cases: {},
        casesWithoutCompleteFacilityAfter24Hours: {},
        casesWithoutCompleteHouseholdAfter48Hours: {},
        casesWithCompleteHousehold: {},
        timesFromSMSToCaseNotification: [],
        timesFromCaseNotificationToCompleteFacility: [],
        timesFromFacilityToCompleteHousehold: [],
        timesFromSMSToCompleteHousehold: []
      };
    });
    total = {
      caseIds: {},
      cases: {},
      casesWithoutCompleteFacilityAfter24Hours: {},
      casesWithoutCompleteHouseholdAfter48Hours: {},
      casesWithCompleteHousehold: {},
      timesFromSMSToCaseNotification: [],
      timesFromCaseNotificationToCompleteFacility: [],
      timesFromFacilityToCompleteHousehold: [],
      timesFromSMSToCompleteHousehold: []
    };
    return $.couch.db(Coconut.config.database_name()).view("zanzibar-server/resultsByDateWithUserAndCaseId", {
      startkey: options.startDate,
      endkey: options.endDate,
      include_docs: false,
      success: function(results) {
        var successWhenDone;
        _(results.rows).each(function(result) {
          var caseId, user;
          caseId = result.value[1];
          user = result.value[0];
          dataByUser[user].caseIds[caseId] = true;
          dataByUser[user].cases[caseId] = {};
          total.caseIds[caseId] = true;
          return total.cases[caseId] = {};
        });
        _(dataByUser).each(function(userData, user) {
          if (_(dataByUser[user].cases).size() === 0) {
            return delete dataByUser[user];
          }
        });
        successWhenDone = _.after(_(dataByUser).size(), function() {
          return options.success({
            dataByUser: dataByUser,
            total: total
          });
        });
        return _(dataByUser).each(function(userData, user) {
          var caseIds;
          caseIds = _(userData.cases).map(function(foo, caseId) {
            return caseId;
          });
          return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/cases", {
            keys: caseIds,
            include_docs: true,
            error: function(error) {
              return console.error("Error finding cases: " + JSON.stringify(error));
            },
            success: function(result) {
              var caseId, caseResults;
              caseId = null;
              caseResults = [];
              _.each(result.rows, function(row) {
                var malariaCase;
                if ((caseId != null) && caseId !== row.key) {
                  malariaCase = new Case({
                    caseID: caseId,
                    results: caseResults
                  });
                  caseResults = [];
                  userData.cases[caseId] = malariaCase;
                  total.cases[caseId] = malariaCase;
                  if (malariaCase.notCompleteFacilityAfter24Hours()) {
                    userData.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase;
                    total.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase;
                  }
                  if (malariaCase.notFollowedUpAfter48Hours()) {
                    userData.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase;
                    total.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase;
                  }
                  if (malariaCase.followedUp()) {
                    userData.casesWithCompleteHousehold[caseId] = malariaCase;
                    total.casesWithCompleteHousehold[caseId] = malariaCase;
                  }
                  userData.timesFromSMSToCaseNotification.push(malariaCase.timeFromSMStoCaseNotification());
                  userData.timesFromCaseNotificationToCompleteFacility.push(malariaCase.timeFromCaseNotificationToCompleteFacility());
                  userData.timesFromFacilityToCompleteHousehold.push(malariaCase.timeFromFacilityToCompleteHousehold());
                  userData.timesFromSMSToCompleteHousehold.push(malariaCase.timeFromSMSToCompleteHousehold());
                  total.timesFromSMSToCaseNotification.push(malariaCase.timeFromSMStoCaseNotification());
                  total.timesFromCaseNotificationToCompleteFacility.push(malariaCase.timeFromCaseNotificationToCompleteFacility());
                  total.timesFromFacilityToCompleteHousehold.push(malariaCase.timeFromFacilityToCompleteHousehold());
                  total.timesFromSMSToCompleteHousehold.push(malariaCase.timeFromSMSToCompleteHousehold());
                }
                caseResults.push(row.doc);
                return caseId = row.key;
              });
              _(userData.cases).each(function(results, caseId) {
                return _(userData).extend({
                  medianTimeFromSMSToCaseNotification: medianTimeFormatted(userData.timesFromSMSToCaseNotification),
                  medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(userData.timesFromCaseNotificationToCompleteFacility),
                  medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(userData.timesFromFacilityToCompleteHousehold),
                  medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(userData.timesFromSMSToCompleteHousehold),
                  medianTimeFromSMSToCaseNotificationSeconds: medianTime(userData.timesFromSMSToCaseNotification),
                  medianTimeFromCaseNotificationToCompleteFacilitySeconds: medianTime(userData.timesFromCaseNotificationToCompleteFacility),
                  medianTimeFromFacilityToCompleteHouseholdSeconds: medianTime(userData.timesFromFacilityToCompleteHousehold),
                  medianTimeFromSMSToCompleteHouseholdSeconds: medianTime(userData.timesFromSMSToCompleteHousehold)
                });
              });
              _(total).extend({
                medianTimeFromSMSToCaseNotification: medianTimeFormatted(total.timesFromSMSToCaseNotification),
                medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(total.timesFromCaseNotificationToCompleteFacility),
                medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(total.timesFromFacilityToCompleteHousehold),
                medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(total.timesFromSMSToCompleteHousehold),
                medianTimeFromSMSToCaseNotificationSeconds: medianTime(total.timesFromSMSToCaseNotification),
                medianTimeFromCaseNotificationToCompleteFacilitySeconds: medianTime(total.timesFromCaseNotificationToCompleteFacility),
                medianTimeFromFacilityToCompleteHouseholdSeconds: medianTime(total.timesFromFacilityToCompleteHousehold),
                medianTimeFromSMSToCompleteHouseholdSeconds: medianTime(total.timesFromSMSToCompleteHousehold)
              });
              return successWhenDone();
            }
          });
        });
      }
    });
  };

  return Reports;

})();
