var Reports,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Reports = (function() {
  function Reports() {
    this.casesAggregatedForAnalysis = __bind(this.casesAggregatedForAnalysis, this);
    this.casesAggregatedForAnalysisByShehia = __bind(this.casesAggregatedForAnalysisByShehia, this);
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

  Reports.prototype.casesAggregatedForAnalysisByShehia = function(options) {
    var data;
    data = {};
    options.finished = options.success;
    return this.getCases(_.extend(options, {
      success: (function(_this) {
        return function(cases) {
          var IRSThresholdInMonths, shehias;
          IRSThresholdInMonths = 6;
          data.followupsByShehia = {};
          data.passiveCasesByShehia = {};
          data.agesByShehia = {};
          data.genderByShehia = {};
          data.netsAndIRSByShehia = {};
          data.travelByShehia = {};
          data.totalPositiveCasesByShehia = {};
          shehias = GeoHierarchy.allShehias();
          shehias = _.map(GeoHierarchy.findAllForLevel("SHEHIA"), function(shehia) {
            return "" + shehia.SHEHIA + ":" + shehia.DISTRICT;
          });
          shehias = shehias.concat(_.map(GeoHierarchy.allDistricts(), function(district) {
            return "UNKNOWN:" + district;
          }));
          shehias.push("ALL");
          _.each(shehias, function(shehia) {
            data.followupsByShehia[shehia] = {
              allCases: [],
              casesFollowedUp: [],
              casesNotFollowedUp: [],
              missingUssdNotification: [],
              missingCaseNotification: []
            };
            data.passiveCasesByShehia[shehia] = {
              indexCases: [],
              householdMembers: [],
              passiveCases: []
            };
            data.agesByShehia[shehia] = {
              underFive: [],
              fiveToFifteen: [],
              fifteenToTwentyFive: [],
              overTwentyFive: [],
              unknown: []
            };
            data.genderByShehia[shehia] = {
              male: [],
              female: [],
              unknown: []
            };
            data.netsAndIRSByShehia[shehia] = {
              sleptUnderNet: [],
              recentIRS: []
            };
            data.travelByShehia[shehia] = {
              travelReported: []
            };
            return data.totalPositiveCasesByShehia[shehia] = [];
          });
          _.each(cases, function(malariaCase) {
            var completedHouseholdMembers, positiveCasesAtHousehold, shehia, _ref, _ref1;
            shehia = malariaCase.shehia() || "UNKNOWN";
            shehia = "" + shehia + ":" + (malariaCase.district());
            if (!data.followupsByShehia[shehia]) {
              shehia = "UNKNOWN:" + (malariaCase.district());
            }
            data.followupsByShehia[shehia].allCases.push(malariaCase);
            data.followupsByShehia["ALL"].allCases.push(malariaCase);
            if (((_ref = malariaCase["Household"]) != null ? _ref.complete : void 0) === "true") {
              data.followupsByShehia[shehia].casesFollowedUp.push(malariaCase);
              data.followupsByShehia["ALL"].casesFollowedUp.push(malariaCase);
            } else {
              data.followupsByShehia[shehia].casesNotFollowedUp.push(malariaCase);
              data.followupsByShehia["ALL"].casesNotFollowedUp.push(malariaCase);
            }
            if (malariaCase["USSD Notification"] == null) {
              data.followupsByShehia[shehia].missingUssdNotification.push(malariaCase);
              data.followupsByShehia["ALL"].missingUssdNotification.push(malariaCase);
            }
            if (malariaCase["Case Notification"] == null) {
              data.followupsByShehia[shehia].missingCaseNotification.push(malariaCase);
              data.followupsByShehia["ALL"].missingCaseNotification.push(malariaCase);
            }
            if (((_ref1 = malariaCase["Household"]) != null ? _ref1.complete : void 0) === "true") {
              data.passiveCasesByShehia[shehia].indexCases.push(malariaCase);
              data.passiveCasesByShehia["ALL"].indexCases.push(malariaCase);
              if (malariaCase["Household Members"] != null) {
                completedHouseholdMembers = _.where(malariaCase["Household Members"], {
                  complete: "true"
                });
                data.passiveCasesByShehia[shehia].householdMembers = data.passiveCasesByShehia[shehia].householdMembers.concat(completedHouseholdMembers);
                data.passiveCasesByShehia["ALL"].householdMembers = data.passiveCasesByShehia["ALL"].householdMembers.concat(completedHouseholdMembers);
              }
              positiveCasesAtHousehold = malariaCase.positiveCasesAtHousehold();
              data.passiveCasesByShehia[shehia].passiveCases = data.passiveCasesByShehia[shehia].passiveCases.concat(positiveCasesAtHousehold);
              data.passiveCasesByShehia["ALL"].passiveCases = data.passiveCasesByShehia["ALL"].passiveCases.concat(positiveCasesAtHousehold);
              return _.each(malariaCase.positiveCasesIncludingIndex(), function(positiveCase) {
                var age, _ref2, _ref3;
                data.totalPositiveCasesByShehia[shehia].push(positiveCase);
                data.totalPositiveCasesByShehia["ALL"].push(positiveCase);
                if (positiveCase.Age != null) {
                  age = parseInt(positiveCase.Age);
                  if (age < 5) {
                    data.agesByShehia[shehia].underFive.push(positiveCase);
                    data.agesByShehia["ALL"].underFive.push(positiveCase);
                  } else if (age < 15) {
                    data.agesByShehia[shehia].fiveToFifteen.push(positiveCase);
                    data.agesByShehia["ALL"].fiveToFifteen.push(positiveCase);
                  } else if (age < 25) {
                    data.agesByShehia[shehia].fifteenToTwentyFive.push(positiveCase);
                    data.agesByShehia["ALL"].fifteenToTwentyFive.push(positiveCase);
                  } else if (age >= 25) {
                    data.agesByShehia[shehia].overTwentyFive.push(positiveCase);
                    data.agesByShehia["ALL"].overTwentyFive.push(positiveCase);
                  }
                } else {
                  if (!positiveCase.age) {
                    data.agesByShehia[shehia].unknown.push(positiveCase);
                  }
                  if (!positiveCase.age) {
                    data.agesByShehia["ALL"].unknown.push(positiveCase);
                  }
                }
                if (positiveCase.Sex === "Male") {
                  data.genderByShehia[shehia].male.push(positiveCase);
                  data.genderByShehia["ALL"].male.push(positiveCase);
                } else if (positiveCase.Sex === "Female") {
                  data.genderByShehia[shehia].female.push(positiveCase);
                  data.genderByShehia["ALL"].female.push(positiveCase);
                } else {
                  data.genderByShehia[shehia].unknown.push(positiveCase);
                  data.genderByShehia["ALL"].unknown.push(positiveCase);
                }
                if (positiveCase.SleptunderLLINlastnight === "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight === "Yes") {
                  data.netsAndIRSByShehia[shehia].sleptUnderNet.push(positiveCase);
                  data.netsAndIRSByShehia["ALL"].sleptUnderNet.push(positiveCase);
                }
                if (positiveCase.LastdateofIRS && positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/)) {
                  if ((new moment).subtract('months', Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))) {
                    data.netsAndIRSByShehia[shehia].recentIRS.push(positiveCase);
                    data.netsAndIRSByShehia["ALL"].recentIRS.push(positiveCase);
                  }
                }
                if (((_ref2 = positiveCase.TravelledOvernightinpastmonth) != null ? _ref2.match(/yes/i) : void 0) || ((_ref3 = positiveCase.OvernightTravelinpastmonth) != null ? _ref3.match(/yes/i) : void 0)) {
                  data.travelByShehia[shehia].travelReported.push(positiveCase);
                  return data.travelByShehia["ALL"].travelReported.push(positiveCase);
                }
              });
            }
          });
          return options.finished(data);
        };
      })(this)
    }));
  };

  Reports.prototype.casesAggregatedForAnalysis = function(options) {
    var data;
    data = {};
    options.finished = options.success;
    return this.getCases(_.extend(options, {
      success: (function(_this) {
        return function(cases) {
          var IRSThresholdInMonths, districts;
          IRSThresholdInMonths = 6;
          data.followupsByDistrict = {};
          data.passiveCasesByDistrict = {};
          data.agesByDistrict = {};
          data.genderByDistrict = {};
          data.netsAndIRSByDistrict = {};
          data.travelByDistrict = {};
          data.totalPositiveCasesByDistrict = {};
          districts = GeoHierarchy.allDistricts();
          districts.push("UNKNOWN");
          districts.push("ALL");
          _.each(districts, function(district) {
            data.followupsByDistrict[district] = {
              allCases: [],
              casesWithCompleteFacilityVisit: [],
              casesWithoutCompleteFacilityVisit: [],
              casesWithCompleteHouseholdVisit: [],
              casesWithoutCompleteHouseholdVisit: [],
              missingUssdNotification: [],
              missingCaseNotification: []
            };
            data.passiveCasesByDistrict[district] = {
              indexCases: [],
              householdMembers: [],
              passiveCases: []
            };
            data.agesByDistrict[district] = {
              underFive: [],
              fiveToFifteen: [],
              fifteenToTwentyFive: [],
              overTwentyFive: [],
              unknown: []
            };
            data.genderByDistrict[district] = {
              male: [],
              female: [],
              unknown: []
            };
            data.netsAndIRSByDistrict[district] = {
              sleptUnderNet: [],
              recentIRS: []
            };
            data.travelByDistrict[district] = {
              travelReported: []
            };
            return data.totalPositiveCasesByDistrict[district] = [];
          });
          _.each(cases, function(malariaCase) {
            var completedHouseholdMembers, district, positiveCasesAtHousehold, _ref, _ref1, _ref2;
            district = malariaCase.district() || "UNKNOWN";
            data.followupsByDistrict[district].allCases.push(malariaCase);
            data.followupsByDistrict["ALL"].allCases.push(malariaCase);
            if (((_ref = malariaCase["Facility"]) != null ? _ref.complete : void 0) === "true") {
              data.followupsByDistrict[district].casesWithCompleteFacilityVisit.push(malariaCase);
              data.followupsByDistrict["ALL"].casesWithCompleteFacilityVisit.push(malariaCase);
            } else {
              data.followupsByDistrict[district].casesWithoutCompleteFacilityVisit.push(malariaCase);
              data.followupsByDistrict["ALL"].casesWithoutCompleteFacilityVisit.push(malariaCase);
            }
            if (((_ref1 = malariaCase["Household"]) != null ? _ref1.complete : void 0) === "true") {
              data.followupsByDistrict[district].casesWithCompleteHouseholdVisit.push(malariaCase);
              data.followupsByDistrict["ALL"].casesWithCompleteHouseholdVisit.push(malariaCase);
            } else {
              data.followupsByDistrict[district].casesWithoutCompleteHouseholdVisit.push(malariaCase);
              data.followupsByDistrict["ALL"].casesWithoutCompleteHouseholdVisit.push(malariaCase);
            }
            if (malariaCase["USSD Notification"] == null) {
              data.followupsByDistrict[district].missingUssdNotification.push(malariaCase);
              data.followupsByDistrict["ALL"].missingUssdNotification.push(malariaCase);
            }
            if (malariaCase["Case Notification"] == null) {
              data.followupsByDistrict[district].missingCaseNotification.push(malariaCase);
              data.followupsByDistrict["ALL"].missingCaseNotification.push(malariaCase);
            }
            if (((_ref2 = malariaCase["Household"]) != null ? _ref2.complete : void 0) === "true") {
              data.passiveCasesByDistrict[district].indexCases.push(malariaCase);
              data.passiveCasesByDistrict["ALL"].indexCases.push(malariaCase);
              if (malariaCase["Household Members"] != null) {
                completedHouseholdMembers = _.where(malariaCase["Household Members"], {
                  complete: "true"
                });
                data.passiveCasesByDistrict[district].householdMembers = data.passiveCasesByDistrict[district].householdMembers.concat(completedHouseholdMembers);
                data.passiveCasesByDistrict["ALL"].householdMembers = data.passiveCasesByDistrict["ALL"].householdMembers.concat(completedHouseholdMembers);
              }
              positiveCasesAtHousehold = malariaCase.positiveCasesAtHousehold();
              data.passiveCasesByDistrict[district].passiveCases = data.passiveCasesByDistrict[district].passiveCases.concat(positiveCasesAtHousehold);
              data.passiveCasesByDistrict["ALL"].passiveCases = data.passiveCasesByDistrict["ALL"].passiveCases.concat(positiveCasesAtHousehold);
              return _.each(malariaCase.positiveCasesIncludingIndex(), function(positiveCase) {
                var age, _ref3, _ref4;
                data.totalPositiveCasesByDistrict[district].push(positiveCase);
                data.totalPositiveCasesByDistrict["ALL"].push(positiveCase);
                if (positiveCase.Age != null) {
                  age = parseInt(positiveCase.Age);
                  if (age < 5) {
                    data.agesByDistrict[district].underFive.push(positiveCase);
                    data.agesByDistrict["ALL"].underFive.push(positiveCase);
                  } else if (age < 15) {
                    data.agesByDistrict[district].fiveToFifteen.push(positiveCase);
                    data.agesByDistrict["ALL"].fiveToFifteen.push(positiveCase);
                  } else if (age < 25) {
                    data.agesByDistrict[district].fifteenToTwentyFive.push(positiveCase);
                    data.agesByDistrict["ALL"].fifteenToTwentyFive.push(positiveCase);
                  } else if (age >= 25) {
                    data.agesByDistrict[district].overTwentyFive.push(positiveCase);
                    data.agesByDistrict["ALL"].overTwentyFive.push(positiveCase);
                  }
                } else {
                  if (!positiveCase.age) {
                    data.agesByDistrict[district].unknown.push(positiveCase);
                  }
                  if (!positiveCase.age) {
                    data.agesByDistrict["ALL"].unknown.push(positiveCase);
                  }
                }
                if (positiveCase.Sex === "Male") {
                  data.genderByDistrict[district].male.push(positiveCase);
                  data.genderByDistrict["ALL"].male.push(positiveCase);
                } else if (positiveCase.Sex === "Female") {
                  data.genderByDistrict[district].female.push(positiveCase);
                  data.genderByDistrict["ALL"].female.push(positiveCase);
                } else {
                  data.genderByDistrict[district].unknown.push(positiveCase);
                  data.genderByDistrict["ALL"].unknown.push(positiveCase);
                }
                if (positiveCase.SleptunderLLINlastnight === "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight === "Yes") {
                  data.netsAndIRSByDistrict[district].sleptUnderNet.push(positiveCase);
                  data.netsAndIRSByDistrict["ALL"].sleptUnderNet.push(positiveCase);
                }
                if (positiveCase.LastdateofIRS && positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/)) {
                  if ((new moment).subtract('months', Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))) {
                    data.netsAndIRSByDistrict[district].recentIRS.push(positiveCase);
                    data.netsAndIRSByDistrict["ALL"].recentIRS.push(positiveCase);
                  }
                }
                if (((_ref3 = positiveCase.TravelledOvernightinpastmonth) != null ? _ref3.match(/yes/i) : void 0) || ((_ref4 = positiveCase.OvernightTravelinpastmonth) != null ? _ref4.match(/yes/i) : void 0)) {
                  data.travelByDistrict[district].travelReported.push(positiveCase);
                  return data.travelByDistrict["ALL"].travelReported.push(positiveCase);
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
        return options.success((_ref = cases.followupsByDistrict["ALL"]) != null ? _ref.casesWithoutCompleteHouseholdVisit : void 0);
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
        return options.success((_ref = cases.followupsByDistrict["UNKNOWN"]) != null ? _ref.casesWithoutCompleteHouseholdVisit : void 0);
      }
    });
  };

  return Reports;

})();
