var Reports,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Reports = (function() {
  function Reports() {
    this.casesAggregatedForAnalysis = __bind(this.casesAggregatedForAnalysis, this);
    this.getCases = __bind(this.getCases, this);
  }

  Reports.prototype.positiveCaseLocations = function(options) {
    return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/positiveCaseLocations", {
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
            _results.push(console.log(cluster[100].length + " cases within 100 meters of one another"));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      }
    });
  };

  Reports.prototype.getCases = function(options) {
    return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/caseIDsByDate", {
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get("date_format")),
      endkey: options.startDate,
      descending: true,
      include_docs: false,
      success: (function(_this) {
        return function(result) {
          var caseIDs;
          caseIDs = _.unique(_.pluck(result.rows, "value"));
          return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/cases", {
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
              missingCaseNotification: [],
              noFacilityFollowupWithin24Hours: [],
              noHouseholdFollowupWithin48Hours: []
            };
            data.passiveCases[aggregationName] = {
              indexCases: [],
              indexCaseHouseholdMembers: [],
              positiveCasesAtIndexHousehold: [],
              neighborHouseholds: [],
              neighborHouseholdMembers: [],
              positiveCasesAtNeighborHouseholds: []
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
              "No": [],
              "Yes within Zanzibar": [],
              "Yes outside Zanzibar": [],
              "Yes within and outside Zanzibar": [],
              "Any travel": [],
              "Not Applicable": []
            };
            return data.totalPositiveCases[aggregationName] = [];
          });
          _.each(cases, function(malariaCase) {
            var caseLocation, completeIndexCaseHouseholdMembers, completeNeighborHouseholdMembers, completeNeighborHouseholds, positiveCasesAtIndexHousehold, _ref, _ref1, _ref2;
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
            if (malariaCase.notCompleteFacilityAfter24Hours()) {
              data.followups[caseLocation].noFacilityFollowupWithin24Hours.push(malariaCase);
              data.followups["ALL"].noFacilityFollowupWithin24Hours.push(malariaCase);
            }
            if (malariaCase.notFollowedUpAfter48Hours()) {
              data.followups[caseLocation].noHouseholdFollowupWithin48Hours.push(malariaCase);
              data.followups["ALL"].noHouseholdFollowupWithin48Hours.push(malariaCase);
            }
            if (((_ref2 = malariaCase["Household"]) != null ? _ref2.complete : void 0) === "true") {
              data.passiveCases[caseLocation].indexCases.push(malariaCase);
              data.passiveCases["ALL"].indexCases.push(malariaCase);
              completeIndexCaseHouseholdMembers = malariaCase.completeIndexCaseHouseholdMembers();
              data.passiveCases[caseLocation].indexCaseHouseholdMembers = data.passiveCases[caseLocation].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers);
              data.passiveCases["ALL"].indexCaseHouseholdMembers = data.passiveCases["ALL"].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers);
              positiveCasesAtIndexHousehold = malariaCase.positiveCasesAtIndexHousehold();
              data.passiveCases[caseLocation].positiveCasesAtIndexHousehold = data.passiveCases[caseLocation].positiveCasesAtIndexHousehold.concat(positiveCasesAtIndexHousehold);
              data.passiveCases["ALL"].positiveCasesAtIndexHousehold = data.passiveCases["ALL"].positiveCasesAtIndexHousehold.concat(positiveCasesAtIndexHousehold);
              completeNeighborHouseholds = malariaCase.completeNeighborHouseholds();
              data.passiveCases[caseLocation].neighborHouseholds = data.passiveCases[caseLocation].neighborHouseholds.concat(completeNeighborHouseholds);
              data.passiveCases["ALL"].neighborHouseholds = data.passiveCases["ALL"].neighborHouseholds.concat(completeNeighborHouseholds);
              completeNeighborHouseholdMembers = malariaCase.completeNeighborHouseholdMembers();
              data.passiveCases[caseLocation].neighborHouseholdMembers = data.passiveCases[caseLocation].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers);
              data.passiveCases["ALL"].neighborHouseholdMembers = data.passiveCases["ALL"].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers);
              return _.each(malariaCase.positiveCasesIncludingIndex(), function(positiveCase) {
                var age;
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
                if (positiveCase.TravelledOvernightinpastmonth != null) {
                  data.travel[caseLocation][positiveCase.TravelledOvernightinpastmonth].push(positiveCase);
                  if (positiveCase.TravelledOvernightinpastmonth.match(/Yes/)) {
                    data.travel[caseLocation]["Any travel"].push(positiveCase);
                  }
                  data.travel["ALL"][positiveCase.TravelledOvernightinpastmonth].push(positiveCase);
                  if (positiveCase.TravelledOvernightinpastmonth.match(/Yes/)) {
                    return data.travel["ALL"]["Any travel"].push(positiveCase);
                  }
                } else if (positiveCase.OvernightTravelinpastmonth) {
                  data.travel[caseLocation][positiveCase.OvernightTravelinpastmonth].push(positiveCase);
                  if (positiveCase.OvernightTravelinpastmonth.match(/Yes/)) {
                    data.travel[caseLocation]["Any travel"].push(positiveCase);
                  }
                  data.travel["ALL"][positiveCase.OvernightTravelinpastmonth].push(positiveCase);
                  if (positiveCase.OvernightTravelinpastmonth.match(/Yes/)) {
                    return data.travel["ALL"]["Any travel"].push(positiveCase);
                  }
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
    return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/errorsByDate", {
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
          return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/cases", {
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

  Reports.aggregateWeeklyReports = function(options) {
    var aggregationArea, aggregationPeriod, endDate, endWeek, endYear, startDate, startWeek, startYear;
    startDate = moment(options.startDate);
    startYear = startDate.format("YYYY");
    startWeek = startDate.format("ww");
    endDate = moment(options.endDate).endOf("day");
    endYear = endDate.format("YYYY");
    endWeek = endDate.format("ww");
    aggregationArea = options.aggregationArea;
    aggregationPeriod = options.aggregationPeriod;
    return $.couch.db(Coconut.config.database_name()).view("zanzibar-server/weeklyDataBySubmitDate", {
      startkey: [startYear, startWeek],
      endkey: [endYear, endWeek],
      include_docs: true,
      success: (function(_this) {
        return function(results) {
          var aggregatedData, cumulativeFields;
          cumulativeFields = {
            "All OPD < 5": 0,
            "Mal POS < 5": 0,
            "Mal NEG < 5": 0,
            "All OPD >= 5": 0,
            "Mal POS >= 5": 0,
            "Mal NEG >= 5": 0
          };
          aggregatedData = {};
          _(results.rows).each(function(row) {
            var area, date, period, weeklyReport;
            weeklyReport = row.doc;
            date = moment().year(weeklyReport.Year).week(weeklyReport.Week);
            period = (function() {
              switch (aggregationPeriod) {
                case "Week":
                  return date.format("YYYY-ww");
                case "Month":
                  return date.format("YYYY-MM");
                case "Year":
                  return date.format("YYYY");
              }
            })();
            area = weeklyReport[aggregationArea];
            if (aggregationArea === "District") {
              area = GeoHierarchy.swahiliDistrictName(area);
            }
            if (!aggregatedData[period]) {
              aggregatedData[period] = {};
            }
            if (!aggregatedData[period][area]) {
              aggregatedData[period][area] = _(cumulativeFields).clone();
            }
            return _(_(cumulativeFields).keys()).each(function(field) {
              return aggregatedData[period][area][field] += parseInt(weeklyReport[field]);
            });
          });
          return options.success({
            fields: _(cumulativeFields).keys(),
            data: aggregatedData
          });
        };
      })(this)
    });
  };

  Reports.aggregatePositiveFacilityCases = function(options) {
    var aggregationArea, aggregationPeriod;
    aggregationArea = options.aggregationArea;
    aggregationPeriod = options.aggregationPeriod;
    return $.couch.db(Coconut.config.database_name()).view("zanzibar-server/positiveFacilityCasesByDate", {
      startkey: options.startDate,
      endkey: options.endDate,
      include_docs: false,
      success: function(result) {
        var aggregatedData;
        aggregatedData = {};
        _.each(result.rows, function(row) {
          var area, caseId, date, facility, period;
          date = moment(row.key);
          period = (function() {
            switch (aggregationPeriod) {
              case "Week":
                return date.format("YYYY-ww");
              case "Month":
                return date.format("YYYY-MM");
              case "Year":
                return date.format("YYYY");
            }
          })();
          caseId = row.value[0];
          facility = row.value[1];
          area = (function() {
            switch (aggregationArea) {
              case "Zone":
                return FacilityHierarchy.getZone(facility);
              case "District":
                return FacilityHierarchy.getDistrict(facility);
              case "Facility":
                return facility;
            }
          })();
          if (area === null) {
            area = "Unknown";
          }
          if (!aggregatedData[period]) {
            aggregatedData[period] = {};
          }
          if (!aggregatedData[period][area]) {
            aggregatedData[period][area] = [];
          }
          return aggregatedData[period][area].push(caseId);
        });
        return options.success(aggregatedData);
      }
    });
  };

  Reports.aggregateWeeklyReportsAndFacilityCases = function(options) {
    options.localSuccess = options.success;
    options.success = function(data) {
      options.success = function(facilityCaseData) {
        data.fields.push("Facility Followed-Up Positive Cases");
        _(facilityCaseData).each(function(areas, period) {
          return _(areas).each(function(positiveFacilityCases, area) {
            if (!data.data[period]) {
              data.data[period] = {};
            }
            if (!data.data[period][area]) {
              data.data[period][area] = {};
            }
            return data.data[period][area]["Facility Followed-Up Positive Cases"] = positiveFacilityCases;
          });
        });
        console.log(data);
        return options.localSuccess(data);
      };
      return Reports.aggregatePositiveFacilityCases(options);
    };
    return Reports.aggregateWeeklyReports(options);
  };

  return Reports;

})();
