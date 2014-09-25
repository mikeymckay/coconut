var ReportView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ReportView = (function(_super) {
  __extends(ReportView, _super);

  function ReportView() {
    this.weeklyReports = __bind(this.weeklyReports, this);
    this.tabletSync = __bind(this.tabletSync, this);
    this.casesWithUnknownDistricts = __bind(this.casesWithUnknownDistricts, this);
    this.casesWithoutCompleteHouseholdVisit = __bind(this.casesWithoutCompleteHouseholdVisit, this);
    this.systemErrors = __bind(this.systemErrors, this);
    this.updateAnalysis = __bind(this.updateAnalysis, this);
    this.users = __bind(this.users, this);
    this.alerts = __bind(this.alerts, this);
    this.renderAlertStructure = __bind(this.renderAlertStructure, this);
    this.getCases = __bind(this.getCases, this);
    this.render = __bind(this.render, this);
    this.update = __bind(this.update, this);
    return ReportView.__super__.constructor.apply(this, arguments);
  }

  ReportView.prototype.initialize = function() {
    return $("html").append("<style> .cases{ display: none; USSD} </style>");
  };

  ReportView.prototype.el = '#content';

  ReportView.prototype.events = {
    "change #reportOptions": "update",
    "change #summaryField1": "summarySelectorChanged",
    "change #summaryField2": "summarySelector2Changed",
    "change #cluster": "updateCluster",
    "click .toggleDisaggregation": "toggleDisaggregation",
    "click .same-cell-disaggregatable": "toggleDisaggregationSameCell",
    "click .toggle-trend-data": "toggleTrendData",
    "click #downloadMap": "downloadMap",
    "click #downloadLargePembaMap": "downloadLargePembaMap",
    "click #downloadLargeUngujaMap": "downloadLargeUngujaMap",
    "click button:contains(Pemba)": "zoomPemba",
    "click button:contains(Unguja)": "zoomUnguja",
    "change [name=aggregationType]": "updateAnalysis"
  };

  ReportView.prototype.updateCluster = function() {
    this.updateUrl("cluster", $("#cluster").val());
    return Coconut.router.navigate(url, true);
  };

  ReportView.prototype.zoomPemba = function() {
    this.map.fitBounds(this.bounds["Pemba"]);
    this.updateUrl("showIsland", "Pemba");
    return Coconut.router.navigate(url, false);
  };

  ReportView.prototype.zoomUnguja = function() {
    this.map.fitBounds(this.bounds["Unguja"]);
    this.updateUrl("showIsland", "Unguja");
    return Coconut.router.navigate(url, false);
  };

  ReportView.prototype.updateUrl = function(property, value) {
    var regExp, url, urlHash;
    urlHash = document.location.hash;
    url = urlHash.match(property) ? (regExp = new RegExp("" + property + "\\/.*?\\/"), urlHash.replace(regExp, "" + property + "/" + value + "/")) : urlHash + ("/" + property + "/" + value + "/");
    return document.location.hash = url;
  };

  ReportView.prototype.updateUrlShowPlace = function(place) {
    var url, urlHash;
    urlHash = document.location.hash;
    url = urlHash.match(/showIsland/) ? urlHash.replace(/showIsland\/.*?\//, "showIsland/" + place + "/") : urlHash + ("/showIsland/" + place + "/");
    document.location.hash = url;
    return Coconut.router.navigate(url, false);
  };

  ReportView.prototype.downloadLargePembaMap = function() {
    this.updateUrl("showIsland", "Pemba");
    this.updateUrl("mapWidth", "2000px");
    return this.updateUrl("mapHeight", "4000px");
  };

  ReportView.prototype.downloadLargeUngujaMap = function() {
    this.updateUrl("showIsland", "Unguja");
    this.updateUrl("mapWidth", "2000px");
    return this.updateUrl("mapHeight", "4000px");
  };

  ReportView.prototype.downloadMap = function() {
    $("#downloadMap").html("Generating downloadable map...");
    return html2canvas($('#map'), {
      width: this.mapWidth,
      height: this.mapHeight,
      proxy: '/map_proxy/proxy.php',
      onrendered: function(canvas) {
        $("#mapData").attr("href", canvas.toDataURL("image/png"));
        return $("#mapData")[0].click();
      }
    });
  };

  ReportView.prototype.toggleTrendData = function() {
    if ($(".toggle-trend-data").html() === "Show trend data") {
      $(".data").show();
      return $(".toggle-trend-data").html("Hide trend data");
    } else {
      $(".data").hide();
      $(".period-0.data").show();
      return $(".toggle-trend-data").html("Show trend data");
    }
  };

  ReportView.prototype.hideSublocations = function() {
    var hide;
    hide = false;
    return _.each(this.locationTypes, function(location) {
      if (hide) {
        $("#row-" + location).hide();
      }
      if ($("#" + location).val() === "ALL") {
        return hide = true;
      }
    });
  };

  ReportView.prototype.update = function() {
    var reportOptions, url;
    reportOptions = {
      startDate: $('#start').val(),
      endDate: $('#end').val(),
      reportType: $('#report-type :selected').text(),
      cluster: $("#cluster").val(),
      summaryField1: $("#summaryField1").val()
    };
    _.each(this.locationTypes, function(location) {
      return reportOptions[location] = $("#" + location + " :selected").text();
    });
    url = "reports/" + _.map(reportOptions, function(value, key) {
      return "" + key + "/" + (escape(value));
    }).join("/");
    return Coconut.router.navigate(url, true);
  };

  ReportView.prototype.render = function(options) {
    var selectedLocations;
    this.reportOptions = options;
    this.locationTypes = "region, district, constituan, shehia".split(/, /);
    _.each(this.locationTypes, function(option) {
      if (options[option] === void 0) {
        return this[option] = "ALL";
      } else {
        return this[option] = unescape(options[option]);
      }
    });
    this.reportType = options.reportType || "dashboard";
    this.startDate = options.startDate || moment(new Date).subtract('days', 7).format("YYYY-MM-DD");
    this.endDate = options.endDate || moment(new Date).format("YYYY-MM-DD");
    this.cluster = options.cluster || "off";
    this.summaryField1 = options.summaryField1;
    this.mapWidth = options.mapWidth || "100%";
    this.mapHeight = options.mapHeight || $(window).height();
    this.$el.html("<style> table.results th.header, table.results td{ font-size:150%; } .malaria-positive{ background-color: pink; } </style> <table id='reportOptions'></table> <div id='reportContents'></div>");
    $("#reportOptions").append(this.formFilterTemplate({
      id: "start",
      label: "Start Date",
      form: "<input id='start' class='date' type='text' value='" + this.startDate + "'/>"
    }));
    $("#reportOptions").append(this.formFilterTemplate({
      id: "end",
      label: "End Date",
      form: "<input id='end' class='date' type='text' value='" + this.endDate + "'/>"
    }));
    selectedLocations = {};
    _.each(this.locationTypes, function(locationType) {
      return selectedLocations[locationType] = this[locationType];
    });
    _.each(this.locationTypes, (function(_this) {
      return function(locationType, index) {
        var locationSelectedOneLevelHigher;
        return $("#reportOptions").append(_this.formFilterTemplate({
          type: "location",
          id: locationType,
          label: locationType.capitalize(),
          form: "<select data-role='selector' id='" + locationType + "'> " + (locationSelectedOneLevelHigher = selectedLocations[_this.locationTypes[index - 1]], _.map(["ALL"].concat(_this.hierarchyOptions(locationType, locationSelectedOneLevelHigher)), function(hierarchyOption) {
            return "<option " + (hierarchyOption === selectedLocations[locationType] ? "selected='true'" : void 0) + ">" + hierarchyOption + "</option>";
          }).join("")) + " </select>"
        }));
      };
    })(this));
    this.hideSublocations();
    $("#reportOptions").append(this.formFilterTemplate({
      id: "report-type",
      label: "Report Type",
      form: "<select data-role='selector' id='report-type'> " + (_.map(["dashboard", "locations", "spreadsheet", "summarytables", "analysis", "alerts", "weeklySummary", "periodSummary", "incidenceGraph", "systemErrors", "casesWithoutCompleteHouseholdVisit", "casesWithUnknownDistricts", "tabletSync", "clusters", "pilotNotifications", "users", "weeklyReports"], (function(_this) {
        return function(type) {
          return "<option " + (type === _this.reportType ? "selected='true'" : void 0) + ">" + type + "</option>";
        };
      })(this)).join("")) + " </select>"
    }));
    this[this.reportType]();
    $('div[data-role=fieldcontain]').fieldcontain();
    $('select[data-role=selector]').selectmenu();
    return $('input.date').datebox({
      mode: "calbox",
      dateFormat: "%Y-%m-%d"
    });
  };

  ReportView.prototype.hierarchyOptions = function(locationType, location) {
    if (locationType === "region") {
      return _(GeoHierarchy.root.children).pluck("name");
    }
    return GeoHierarchy.findChildrenNames(locationType.toUpperCase(), location);
  };

  ReportView.prototype.mostSpecificLocationSelected = function() {
    var mostSpecificLocationType, mostSpecificLocationValue;
    mostSpecificLocationType = "region";
    mostSpecificLocationValue = "ALL";
    _.each(this.locationTypes, function(locationType) {
      if (this[locationType] !== "ALL") {
        mostSpecificLocationType = locationType;
        return mostSpecificLocationValue = this[locationType];
      }
    });
    return {
      type: mostSpecificLocationType,
      name: mostSpecificLocationValue
    };
  };

  ReportView.prototype.formFilterTemplate = function(options) {
    return "<tr id='row-" + options.id + "' class='" + options.type + "'> <td> <label style='display:inline' for='" + options.id + "'>" + options.label + "</label> </td> <td style='width:150%'> " + options.form + " </td> </tr>";
  };

  ReportView.prototype.getCases = function(options) {
    var reports;
    reports = new Reports();
    return reports.getCases({
      startDate: this.startDate,
      endDate: this.endDate,
      success: options.success,
      mostSpecificLocation: this.mostSpecificLocationSelected()
    });
  };

  ReportView.prototype.renderAlertStructure = function(alerts_to_check) {
    $("#reportContents").html("<h2>Alerts</h2> <div id='alerts_status' style='padding-bottom:20px;font-size:150%'> <h2>Checking for system alerts:" + (alerts_to_check.join(", ")) + "</h2> </div> <div id='alerts'> " + (_.map(alerts_to_check, function(alert) {
      return "<div id='" + alert + "'><br/></div>";
    }).join("")) + " </div>");
    this.alerts = false;
    return this.afterFinished = _.after(alerts_to_check.length, function() {
      if (this.alerts) {
        return $("#alerts_status").html("<div id='hasAlerts'>Report finished, alerts found.</div>");
      } else {
        return $("#alerts_status").html("<div id='hasAlerts'>Report finished, no alerts found.</div>");
      }
    });
  };

  ReportView.prototype.alerts = function() {
    this.renderAlertStructure("system_errors, not_followed_up, unknown_districts".split(/, */));
    Reports.systemErrors({
      success: (function(_this) {
        return function(errorsByType) {
          if (_(errorsByType).isEmpty()) {
            $("#system_errors").append("No system errors in the past 2 days.");
          } else {
            _this.alerts = true;
            $("#system_errors").append("The following system errors have occurred in the last 2 days: <table style='border:1px solid black' class='system-errors'> <thead> <tr> <th>Time of most recent error</th> <th>Message</th> <th>Number of errors of this type in last 24 hours</th> <th>Source</th> </tr> </thead> <tbody> " + (_.map(errorsByType, function(errorData, errorMessage) {
              return "<tr> <td>" + errorData["Most Recent"] + "</td> <td>" + errorMessage + "</td> <td>" + errorData.count + "</td> <td>" + errorData["Source"] + "</td> </tr>";
            }).join("")) + " </tbody> </table>");
          }
          return _this.afterFinished();
        };
      })(this)
    });
    return Reports.casesWithoutCompleteHouseholdVisit({
      startDate: this.startDate,
      endDate: this.endDate,
      mostSpecificLocation: this.mostSpecificLocationSelected(),
      success: (function(_this) {
        return function(casesWithoutCompleteHouseholdVisit) {
          if (casesWithoutCompleteHouseholdVisit.length === 0) {
            $("#not_followed_up").append("All cases between " + _this.startDate + " and " + _this.endDate + " have been followed up within two days.");
          } else {
            _this.alerts = true;
            $("#not_followed_up").append("The following districts have USSD Notifications that occurred between " + _this.startDate + " and " + _this.endDate + " that have not been followed up after two days. Recommendation call the DMSO: <table  style='border:1px solid black' class='alerts'> <thead> <tr> <th>Facility</th> <th>District</th> <th>Officer</th> <th>Phone number</th> </tr> </thead> <tbody> " + (_.map(casesWithoutCompleteHouseholdVisit, function(malariaCase) {
              var district, user;
              district = malariaCase.district() || "UNKNOWN";
              if (district === "ALL" || district === "UNKNOWN") {
                return "";
              }
              user = Users.where({
                district: district
              });
              if (user.length) {
                user = user[0];
              }
              return "<tr> <td>" + (malariaCase.facility()) + "</td> <td>" + (district.titleize()) + "</td> <td>" + (typeof user.get === "function" ? user.get("name") : void 0) + "</td> <td>" + (typeof user.username === "function" ? user.username() : void 0) + "</td> </tr>";
            }).join("")) + " </tbody> </table>");
          }
          _this.afterFinished();
          return Reports.unknownDistricts({
            startDate: _this.startDate,
            endDate: _this.endDate,
            mostSpecificLocation: _this.mostSpecificLocationSelected(),
            success: function(casesNotFollowedupWithUnknownDistrict) {
              if (casesNotFollowedupWithUnknownDistrict.length === 0) {
                $("#unknown_districts").append("All cases between " + _this.startDate + " and " + _this.endDate + " that have not been followed up have shehias with known districts");
              } else {
                _this.alerts = true;
                $("#unknown_districts").append("The following cases have not been followed up and have shehias with unknown districts (for period " + _this.startDate + " to " + _this.endDate + ". These may be traveling patients or incorrectly spelled shehias. Please contact an administrator if the problem can be resolved by fixing the spelling. <table style='border:1px solid black' class='unknown-districts'> <thead> <tr> <th>Health facility</th> <th>Shehia</th> <th>Case ID</th> </tr> </thead> <tbody> " + (_.map(casesNotFollowedupWithUnknownDistrict, function(caseNotFollowedUpWithUnknownDistrict) {
                  var _ref;
                  console.log(JSON.stringify(caseNotFollowedUpWithUnknownDistrict));
                  return "<tr> <td>" + ((_ref = caseNotFollowedUpWithUnknownDistrict["USSD Notification"]) != null ? _ref.hf.titleize() : void 0) + "</td> <td>" + (caseNotFollowedUpWithUnknownDistrict.shehia().titleize()) + "</td> <td><a href='#show/case/" + caseNotFollowedUpWithUnknownDistrict.caseID + "'>" + caseNotFollowedUpWithUnknownDistrict.caseID + "</a></td> </tr>";
                }).join("")) + " </tbody> </table>");
              }
              return _this.afterFinished();
            }
          });
        };
      })(this)
    });
  };

  ReportView.prototype.clusters = function() {
    var clusterThreshold, reports;
    clusterThreshold = 1000;
    reports = new Reports();
    return reports.positiveCaseLocations({
      startDate: this.startDate,
      endDate: this.endDate,
      success: function(positiveCases) {
        var bar, clusteredCases, foo, result, _i, _len;
        clusteredCases = [];
        console.log(positiveCases);
        for (bar = _i = 0, _len = positiveCases.length; _i < _len; bar = ++_i) {
          foo = positiveCases[bar];
          console.log(foo);
        }
        result = _(positiveCases).map(function(cluster) {
          console.log("ASDAS");
          return console.log(cluster);
        });
        result = _.chain(positiveCases).map(function(cluster, positiveCase) {
          console.log("ASDAS");
          console.log(cluster);
          if (cluster[clusterThreshold].length > 4) {
            console.log(cluster[clusterThreshold]);
            return cluster[clusterThreshold];
          }
          return null;
        }).compact().sortBy(function(cluster) {
          return cluster.length;
        }).map(function(cluster) {
          var positiveCase, _j, _len1;
          console.log(cluster);
          for (_j = 0, _len1 = cluster.length; _j < _len1; _j++) {
            positiveCase = cluster[_j];
            if (clusteredCases[positiveCase.MalariaCaseId]) {
              return null;
            } else {
              clusteredCases[positiveCase.MalariaCaseId] = true;
              return cluster;
            }
          }
        }).compact().value();
        return console.log(result);
      }
    });
  };

  ReportView.prototype.users = function() {
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/users", {
      include_docs: false,
      success: (function(_this) {
        return function(usersView) {
          var averageTime, averageTimeFormatted, dataByUser, medianTime, medianTimeFormatted, total;
          $("#reportContents").html("<style> td.number{ text-align: center; vertical-align: middle; } </style> <div id='users'> <h1>How fast are followups occuring?</h1> <h2>Median</h2> <table style='font-size:150%' class='tablesorter' style=' id='usersReportTotals'> <tbody> <tr class='odd' style='font-weight:bold' id='medianTimeFromSMSToCompleteHousehold'><td>Median time from SMS sent to Complete Household</td></tr> <tr id='cases'><td>Cases</td></tr> <tr class='odd' id='casesWithoutCompleteHousehold'><td>Cases without complete household record</td></tr> <tr id='casesWithCompleteHousehold'><td>Cases with complete household record</td></tr> <tr class='odd' id='medianTimeFromSMSToCaseNotification'><td>Median time from SMS sent to Case Notification on tablet</td></tr> <tr id='medianTimeFromCaseNotificationToCompleteFacility'><td>Median time from Case Notification to Complete Facility</td></tr> <tr class='odd' id='medianTimeFromFacilityToCompleteHousehold'><td>Median time from Complete Facility to Complete Household</td></tr> <tr style='display:none' id='caseIds'><td>Case IDs</td></tr> </tbody> </table> <h2>By User</h2> <table class='tablesorter' style='' id='usersReport'> <thead> <th>Name</th> <th>District</th> <th>Cases</th> <th style='display:none' class='cases'>Case IDs</th> <th>Cases without complete household record</th> <th style='display:none' class='casesWithoutCompleteHousehold'>Case IDs for Cases Without Complete Household</th> <th>Cases with complete household record</th> <th style='display:none' class='casesWithCompleteHousehold'>Case IDs for Cases With Complete Household</th> <th>Median time from SMS sent to Case Notification on tablet</th> <th>Median time from Case Notification to Complete Facility</th> <th>Median time from Complete Facility to Complete Household</th> <th>Median time from SMS sent to Complete Household</th> </thead> <tbody> " + (_(usersView.rows).map(function(user) {
            return "<tr id='" + (user.id.replace(/user\./, "")) + "'> <td>" + (user.value[0] || user.value[1]) + "</td> <td>" + (user.key || "-") + "</td> </tr>";
          }).join("")) + " </tbody> </table> </div>");
          medianTime = function(values) {
            var half;
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
          _(usersView.rows).each(function(user) {
            return dataByUser[user.id.replace(/user\./, "")] = {
              userId: user.id.replace(/user\./, ""),
              caseIds: {},
              cases: {},
              casesWithoutCompleteHousehold: {},
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
            casesWithoutCompleteHousehold: {},
            casesWithCompleteHousehold: {},
            timesFromSMSToCaseNotification: [],
            timesFromCaseNotificationToCompleteFacility: [],
            timesFromFacilityToCompleteHousehold: [],
            timesFromSMSToCompleteHousehold: []
          };
          return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/resultsByDateWithUserAndCaseId", {
            startkey: _this.startDate,
            endkey: _this.endDate,
            include_docs: false,
            success: function(results) {
              var addDataTables;
              _(results.rows).each(function(result) {
                var caseId, user;
                caseId = result.value[1];
                user = result.value[0];
                dataByUser[user].caseIds[caseId] = true;
                dataByUser[user].cases[caseId] = {};
                total.caseIds[caseId] = true;
                return total.cases[caseId] = {};
              });
              addDataTables = _.after(_(dataByUser).size(), function() {
                $("#usersReport").dataTable({
                  aaSorting: [[4, "desc"], [3, "desc"]],
                  iDisplayLength: 50
                });
                return _(total).each(function(value, key) {
                  if (key === "caseIds") {
                    return "";
                  } else if (key === "cases" || key === "casesWithoutCompleteHousehold" || key === "casesWithCompleteHousehold") {
                    return $("tr#" + key).append("<td>" + (_(value).size()) + "</td>");
                  } else {
                    return $("tr#" + key).append("<td>" + value + "</td>");
                  }
                });
              });
              return _(dataByUser).each(function(userData, user) {
                var analyzeAndRender;
                if (_(dataByUser[user].cases).size() === 0) {
                  $("tr#" + user).hide();
                }
                analyzeAndRender = _.after(_(userData.cases).size(), (function(_this) {
                  return function() {
                    var cases;
                    _(userData.cases).each(function(results, caseId) {
                      return _(userData).extend({
                        medianTimeFromSMSToCaseNotification: medianTimeFormatted(userData.timesFromSMSToCaseNotification),
                        medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(userData.timesFromCaseNotificationToCompleteFacility),
                        medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(userData.timesFromFacilityToCompleteHousehold),
                        medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(userData.timesFromSMSToCompleteHousehold)
                      });
                    });
                    _(total).extend({
                      medianTimeFromSMSToCaseNotification: medianTimeFormatted(total.timesFromSMSToCaseNotification),
                      medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(total.timesFromCaseNotificationToCompleteFacility),
                      medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(total.timesFromFacilityToCompleteHousehold),
                      medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(total.timesFromSMSToCompleteHousehold)
                    });
                    $("tr#" + userData.userId).append("<td class='number'><button type='button' onClick='$(this).parent().next().toggle();$(\"th.cases\").toggle()'>" + (_(userData.cases).size()) + "</button></td> <td style='display:none' class='detail'> " + (cases = _(userData.cases).keys(), _(cases).map(function(caseId) {
                      return "<button type='button'><a href='#show/case/" + caseId + "'>" + caseId + "</a></button>";
                    }).join(" ")) + " </td> <td class='number'><button onClick='$(this).parent().next().toggle();$(\"th.casesWithoutCompleteHousehold\").toggle()' type='button'>" + (_(userData.casesWithoutCompleteHousehold).size() || "-") + "</button></td> <td style='display:none' class='casesWithoutCompleteHousehold-detail'> " + (cases = _(userData.casesWithoutCompleteHousehold).keys(), _(cases).map(function(caseId) {
                      return "<button type='button'><a href='#show/case/" + caseId + "'>" + caseId + "</a></button>";
                    }).join(" ")) + " </td> <td class='number'><button onClick='$(this).parent().next().toggle();$(\"th.casesWithCompleteHousehold\").toggle()' type='button'>" + (_(userData.casesWithCompleteHousehold).size() || "-") + "</button></td> <td style='display:none' class='casesWithCompleteHousehold-detail'> " + (cases = _(userData.casesWithCompleteHousehold).keys(), _(cases).map(function(caseId) {
                      return "<button type='button'><a href='#show/case/" + caseId + "'>" + caseId + "</a></button>";
                    }).join(" ")) + " </td> <td class='number'>" + (userData.medianTimeFromSMSToCaseNotification || "-") + "</td> <td class='number'>" + (userData.medianTimeFromCaseNotificationToCompleteFacility || "-") + "</td> <td class='number'>" + (userData.medianTimeFromFacilityToCompleteHousehold || "-") + "</td> <td class='number'>" + (userData.medianTimeFromSMSToCompleteHousehold || "-") + "</td>");
                    return addDataTables();
                  };
                })(this));
                if (_(userData.cases).size() === 0) {
                  analyzeAndRender(userData);
                }
                return _(userData.cases).each(function(foo, caseId) {
                  var malariaCase;
                  malariaCase = new Case({
                    caseID: caseId
                  });
                  return malariaCase.fetch({
                    error: function(error) {
                      return console.log(("Could not load case: (" + caseId + "): ") + JSON.stringify(error));
                    },
                    success: function() {
                      userData.cases[caseId] = malariaCase;
                      if (!malariaCase.followedUp()) {
                        userData.casesWithoutCompleteHousehold[caseId] = malariaCase;
                      }
                      if (malariaCase.followedUp()) {
                        userData.casesWithCompleteHousehold[caseId] = malariaCase;
                      }
                      userData.timesFromSMSToCaseNotification.push(malariaCase.timeFromSMStoCaseNotification());
                      userData.timesFromCaseNotificationToCompleteFacility.push(malariaCase.timeFromCaseNotificationToCompleteFacility());
                      userData.timesFromFacilityToCompleteHousehold.push(malariaCase.timeFromFacilityToCompleteHousehold());
                      userData.timesFromSMSToCompleteHousehold.push(malariaCase.timeFromSMSToCompleteHousehold());
                      total.cases[caseId] = malariaCase;
                      if (!malariaCase.followedUp()) {
                        total.casesWithoutCompleteHousehold[caseId] = malariaCase;
                      }
                      if (malariaCase.followedUp()) {
                        total.casesWithCompleteHousehold[caseId] = malariaCase;
                      }
                      total.timesFromSMSToCaseNotification.push(malariaCase.timeFromSMStoCaseNotification());
                      total.timesFromCaseNotificationToCompleteFacility.push(malariaCase.timeFromCaseNotificationToCompleteFacility());
                      total.timesFromFacilityToCompleteHousehold.push(malariaCase.timeFromFacilityToCompleteHousehold());
                      total.timesFromSMSToCompleteHousehold.push(malariaCase.timeFromSMSToCompleteHousehold());
                      return analyzeAndRender(userData);
                    }
                  });
                });
              });
            }
          });
        };
      })(this)
    });
  };

  ReportView.prototype.locations = function() {
    if ($("#googleMapsLeafletPlugin").length !== 1) {
      _.delay((function(_this) {
        return function() {
          $("body").append("<script id='googleMapsLeafletPlugin' type='text/javascript' src='js-libraries/Google.js'></script>");
          console.log("Satellite ready");
          return _this.layerControl.addBaseLayer(new L.Google('SATELLITE'), "Satellite");
        };
      })(this), 4000);
    }
    $("#reportOptions").append(this.formFilterTemplate({
      id: "cluster",
      label: "Cluster",
      form: "<select name='cluster' id='cluster' data-role='slider'> <option value='off'>Off</option> <option value='on' " + (this.cluster === "on" ? "selected='true'" : '') + "'>On</option> </select>"
    }));
    $("#reportOptions").append("<button>Pemba</button> <button>Unguja</button>");
    $("#reportOptions button").button();
    $("#reportContents").html("Use + - buttons to zoom map. Click and drag to reposition the map. Circles with a darker have multiple cases. Red cases show households with additional positive malaria cases.<br/> <div id='map' style='width:" + this.mapWidth + "; height:" + this.mapHeight + ";'></div> <button id='downloadMap' type='button'>Download Map</button> <button id='downloadLargeUngujaMap' type='button'>Download Large Pemba Map</button> <button id='downloadLargePembaMap' type='button'>Download Large Unguja Map</button> <a id='mapData' download='map.png' style='display:none'>Map</a> <img src='images/loading.gif' style='z-index:100;position:absolute;top:50%;left:50%;margin-left:21px;margin-right:21px' id='tilesLoadingIndicator'/>");
    $("#cluster").slider();
    return this.getCases({
      success: (function(_this) {
        return function(results) {
          var baseLayers, clusterGroup, locations, tileLayer;
          locations = _.compact(_.map(results, function(caseResult) {
            var _ref, _ref1, _ref2, _ref3;
            if ((_ref = caseResult.Household) != null ? _ref["HouseholdLocation-latitude"] : void 0) {
              return {
                MalariaCaseID: caseResult.caseID,
                latitude: (_ref1 = caseResult.Household) != null ? _ref1["HouseholdLocation-latitude"] : void 0,
                longitude: (_ref2 = caseResult.Household) != null ? _ref2["HouseholdLocation-longitude"] : void 0,
                hasAdditionalPositiveCasesAtHousehold: caseResult.hasAdditionalPositiveCasesAtHousehold(),
                date: (_ref3 = caseResult.Household) != null ? _ref3.lastModifiedAt : void 0
              };
            }
          }));
          if (locations.length === 0) {
            $("#map").html("<h2>No location information for the range specified.</h2>");
            return;
          }

          /*
           * Use the average to center the map
          latitudeSum = _.reduce locations, (memo,location) ->
            memo + Number(location.latitude)
          , 0
          
          longitudeSum = _.reduce locations, (memo,location) ->
            memo + Number(location.longitude)
          , 0
          
          map = new L.Map('map', {
            center: new L.LatLng(
              latitudeSum/locations.length,
              longitudeSum/locations.length
            )
            zoom: 9
          })
           */
          _this.map = new L.Map('map');
          _this.bounds = {
            "Pemba": [[-4.8587000, 39.8772333], [-5.4858000, 39.5536000]],
            "Unguja": [[-5.7113500, 39.59], [-6.541, 39.0945000]],
            "Pemba and Unguja": [[-4.8587000, 39.8772333], [-6.4917667, 39.0945000]]
          };
          _this.map.fitBounds(_this.reportOptions.topRight && _this.reportOptions.bottomLeft ? [_this.reportOptions.topRight, _this.reportOptions.bottomLeft] : _this.reportOptions.showIsland ? _this.bounds[_this.reportOptions.showIsland] : _this.bounds["Pemba and Unguja"]);
          tileLayer = new L.TileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            minZoom: 1,
            maxZoom: 12,
            attribution: 'Map data © OpenStreetMap contributors'
          });
          tileLayer.on("loading", function() {
            return $("#tilesLoadingIndicator").show();
          });
          tileLayer.on("load", function() {
            return $("#tilesLoadingIndicator").hide();
          });
          _this.map.addLayer(tileLayer);
          baseLayers = ['OpenStreetMap.Mapnik', 'Stamen.Watercolor', 'Esri.WorldImagery'];
          _this.layerControl = L.control.layers.provided(baseLayers).addTo(_this.map);
          L.Icon.Default.imagePath = 'images';
          if (_this.cluster === "on") {
            clusterGroup = new L.MarkerClusterGroup();
            _.each(locations, function(location) {
              return L.marker([location.latitude, location.longitude]).addTo(clusterGroup).bindPopup("" + location.date + ": <a href='#show/case/" + location.MalariaCaseID + "'>" + location.MalariaCaseID + "</a>");
            });
            return _this.map.addLayer(clusterGroup);
          } else {
            return _.each(locations, function(location) {
              return L.circleMarker([location.latitude, location.longitude], {
                "fillColor": location.hasAdditionalPositiveCasesAtHousehold ? "red" : "",
                "radius": 5
              }).addTo(_this.map).bindPopup("" + location.date + ": <a href='#show/case/" + location.MalariaCaseID + "'>" + location.MalariaCaseID + "</a>");
            });
          }
        };
      })(this)
    });
  };

  ReportView.prototype.spreadsheet = function() {
    $("#row-region").hide();
    $("#reportContents").html("<a id='csv' href='http://spreadsheet.zmcp.org/spreadsheet/" + this.startDate + "/" + this.endDate + "'>Download spreadsheet for " + this.startDate + " to " + this.endDate + "</a>");
    return $("a#csv").button();
  };

  ReportView.prototype.results = function() {
    $("#reportContents").html("<table id='results' class='tablesorter'> <thead> <tr> </tr> </thead> <tbody> </tbody> </table>");
    return this.getCases({
      success: (function(_this) {
        return function(cases) {
          var fields, tableData;
          fields = "MalariaCaseID,LastModifiedAt,Questions".split(",");
          tableData = _.chain(cases).sortBy(function(caseResult) {
            return caseResult.LastModifiedAt();
          }).value().reverse().map(function(caseResult) {
            return _.map(fields, function(field) {
              return caseResult[field]();
            });
          });
          $("table#results thead tr").append("" + (_.map(fields, function(field) {
            return "<th>" + field + "</th>";
          }).join("")));
          return $("table#results tbody").append(_.map(tableData, function(row) {
            return "<tr> " + (_.map(row, function(element, index) {
              return "<td>" + (index === 0 ? "<a href='#show/case/" + element + "'>" + element + "</a>" : element) + "</td>";
            }).join("")) + " </tr>";
          }).join(""));
        };
      })(this)
    });
  };

  ReportView.prototype.getFieldListSelector = function(resultCollection, selectorId) {
    var fields;
    fields = _.chain(resultCollection.toJSON()).map(function(result) {
      return _.keys(result);
    }).flatten().uniq().sort().value();
    fields = _.without(fields, "_id", "_rev");
    return "<br/> Choose a field to summarize:<br/> <select data-role='selector' class='summarySelector' id='" + selectorId + "'> <option></option> " + (_.map(fields, function(field) {
      return "<option id='" + field + "'>" + field + "</option>";
    }).join("")) + " </select>";
  };

  ReportView.prototype.summarytables = function() {
    return Coconut.resultCollection.fetch({
      include_docs: true,
      success: (function(_this) {
        return function() {
          $("#reportContents").html(_this.getFieldListSelector(Coconut.resultCollection, "summaryField1"));
          $('#summaryField1').selectmenu();
          if (_this.summaryField1 != null) {
            $('#summaryField1').val(_this.summaryField1);
            $('#summaryField1').selectmenu("refresh");
            return _this.summarize(_this.summaryField1);
          }
        };
      })(this)
    });
  };

  ReportView.prototype.summarySelectorChanged = function(event) {
    this.summarize($(event.target).find("option:selected").text());
    return this.update();
  };

  ReportView.prototype.summarize = function(field) {
    return this.getCases({
      success: (function(_this) {
        return function(cases) {
          var results;
          results = {};
          _.each(cases, function(caseData) {
            return _.each(caseData.toJSON(), function(value, key) {
              var valuesToCheck;
              valuesToCheck = [];
              if (key === "Household Members") {
                valuesToCheck = value;
              } else {
                valuesToCheck.push(value);
              }
              return _.each(valuesToCheck, function(value, key) {
                if (value[field] != null) {
                  if (results[value[field]] == null) {
                    results[value[field]] = {};
                    results[value[field]]["sums"] = 0;
                    results[value[field]]["resultData"] = [];
                  }
                  results[value[field]]["sums"] += 1;
                  return results[value[field]]["resultData"].push({
                    caseID: caseData.caseID,
                    resultID: value._id
                  });
                }
              });
            });
          });
          if ($("#summaryTables").length !== 1) {
            _this.$el.append("<div id='summaryTables'></div>");
          }
          $("#summaryTables").html("<h2>" + field + "</h2> <table id='summaryTable' class='tablesorter'> <thead> <tr> <th>Value</th> <th>Total</th> <th class='cases'>Cases</th> </tr> </thead> <tbody> " + (_.map(results, function(aggregates, value) {
            return "<tr data-row-value='" + value + "'> <td>" + value + "</td> <td> <button class='toggleDisaggregation'>" + aggregates["sums"] + "</button> </td> <td class='cases'> " + (_.map(aggregates.resultData, function(resultData) {
              return "<a data-result-id='" + resultData.resultID + "' data-case-id='" + resultData.caseID + "' data-row-value='" + value + "' class='case' href='#show/case/" + resultData.caseID + "/" + resultData.resultID + "'>" + resultData.caseID + "</a>";
            }).join("")) + " </td> </tr>";
          }).join("")) + " </tbody> </table> <h3> Disaggregate summary based on another variable </h3>");
          $("#summaryTables").append($("#summaryField1").clone().attr("id", "summaryField2"));
          $("#summaryField2").selectmenu();
          $("button").button();
          $("a").button();
          return _.each($('table tr'), function(row, index) {
            if (index % 2 === 1) {
              return $(row).addClass("odd");
            }
          });
        };
      })(this)
    });
  };

  ReportView.prototype.toggleDisaggregation = function(event) {
    return $(event.target).parents("td").siblings(".cases").toggle();
  };

  ReportView.prototype.toggleDisaggregationSameCell = function(event) {
    return $(event.target).siblings(".cases").toggle();
  };

  ReportView.prototype.summarySelector2Changed = function(event) {
    return this.disaggregateSummary($(event.target).find("option:selected").text());
  };

  ReportView.prototype.disaggregateSummary = function(field) {
    var afterLookups, cases, data, disaggregatedSummaryTable;
    data = {};
    disaggregatedSummaryTable = $("#summaryTable").clone().attr("id", "disaggregatedSummaryTable");
    cases = disaggregatedSummaryTable.find("a.case");
    _.each(cases, function(caseElement) {
      var result, resultID, rowValue;
      caseElement = $(caseElement);
      rowValue = caseElement.attr("data-row-value");
      if (!data[rowValue]) {
        data[rowValue] = {};
      }
      resultID = caseElement.attr("data-result-id");
      result = new Result({
        _id: resultID
      });
      return result.fetch({
        success: function() {
          var caseData, caseID, fieldValue;
          fieldValue = result.get(field);
          if (fieldValue != null) {
            if (!data[rowValue][fieldValue]) {
              data[rowValue][fieldValue] = 0;
            }
            data[rowValue][fieldValue] += 1;
            return afterLookups();
          } else {
            caseID = caseElement.attr("data-case-id");
            caseData = new Case({
              caseID: caseID
            });
            return caseData.fetch({
              success: function() {
                fieldValue = caseData.flatten()[field];
                if (!data[rowValue][fieldValue]) {
                  data[rowValue][fieldValue] = 0;
                }
                data[rowValue][fieldValue] += 1;
                return afterLookups();
              }
            });
          }
        }
      });
    });
    return afterLookups = _.after(cases.length, function() {
      var columns;
      columns = _.uniq(_.flatten(_.map(data, function(row) {
        return _.keys(row);
      })).sort());
      disaggregatedSummaryTable.find("thead tr").append(_.map(columns, function(column) {
        return "<th>" + column + "</th>";
      }).join(""));
      _.each(data, function(value, rowValue) {
        var row;
        row = disaggregatedSummaryTable.find("tbody tr[data-row-value='" + rowValue + "']");
        return _.each(columns, function(column) {
          if (value[column]) {
            return row.append("<td>" + value[column] + "</td>");
          } else {
            return row.append("<td>0</td>");
          }
        });
      });
      return $("#summaryTables").append(disaggregatedSummaryTable);
    });
  };

  ReportView.prototype.createTable = function(headerValues, rows, id) {
    return "<table " + (id != null ? "id=" + id : "") + " class='tablesorter'> <thead> <tr> " + (_.map(headerValues, function(header) {
      return "<th>" + header + "</th>";
    }).join("")) + " </tr> </thead> <tbody> " + rows + " </tbody> </table>";
  };

  ReportView.prototype.incidenceGraph = function() {
    var startDate;
    $("#reportContents").html("<div id='analysis'></div>");
    $("#analysis").append("<style> #chart_container { position: relative; font-family: Arial, Helvetica, sans-serif; } #chart { position: relative; left: 40px; } #y_axis { position: absolute; top: 0; bottom: 0; width: 40px; } </style> <div id='chart_container'> <div id='y_axis'></div> <div id='chart'></div> </div>");
    startDate = moment.utc("2012-07-01");
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/positiveCases", {
      startkey: startDate.year(),
      include_docs: false,
      success: function(result) {
        var casesPerAggregationPeriod, dataForGraph, graph, x_axis, y_axis;
        casesPerAggregationPeriod = {};
        _.each(result.rows, function(row) {
          var aggregationKey, date;
          date = moment(row.key.substr(0, 10));
          if (row.key.substr(0, 2) === "20" && (date != null ? date.isValid() : void 0) && date > startDate && date < new moment()) {
            aggregationKey = date.clone().endOf("week").unix();
            if (!casesPerAggregationPeriod[aggregationKey]) {
              casesPerAggregationPeriod[aggregationKey] = 0;
            }
            return casesPerAggregationPeriod[aggregationKey] += 1;
          }
        });
        dataForGraph = _.map(casesPerAggregationPeriod, function(numberOfCases, date) {
          return {
            x: parseInt(date),
            y: numberOfCases
          };
        });

        /*
        This didn't work -  from http://stackoverflow.com/questions/15791907/how-do-i-get-rickshaw-to-aggregate-data-into-weeks-instead-of-days
        aggregated = d3.nest()
        .key (d) ->
          (new Date(+d.x * 1000)).getMonth()
        .rollup (d) ->
          d3.sum(d, (e) -> return +e.y)
        .entries(dataForGraph)
        .map (d) ->
          {x: +d.key, y: d.values}
         */
        graph = new Rickshaw.Graph({
          element: document.querySelector("#chart"),
          width: 580,
          height: 250,
          series: [
            {
              color: 'steelblue',
              data: dataForGraph
            }
          ]
        });
        x_axis = new Rickshaw.Graph.Axis.Time({
          graph: graph
        });
        y_axis = new Rickshaw.Graph.Axis.Y({
          graph: graph,
          orientation: 'left',
          tickFormat: Rickshaw.Fixtures.Number.formatKMBT,
          element: document.getElementById('y_axis')
        });
        return graph.render();
      }
    });
  };

  ReportView.prototype.weeklySummary = function(options) {
    var currentOptions, previousOptions, previousPreviousOptions, previousPreviousPreviousOptions;
    if (options == null) {
      options = {};
    }
    currentOptions = _.clone(this.reportOptions);
    currentOptions.startDate = moment().day(1).format(Coconut.config.get("date_format"));
    currentOptions.endDate = moment().day(0 + 7).format(Coconut.config.get("date_format"));
    previousOptions = _.clone(this.reportOptions);
    previousOptions.startDate = moment().day(1 - 7).format(Coconut.config.get("date_format"));
    previousOptions.endDate = moment().day(0 + 7 - 7).format(Coconut.config.get("date_format"));
    previousPreviousOptions = _.clone(this.reportOptions);
    previousPreviousOptions.startDate = moment().day(1 - 7 - 7).format(Coconut.config.get("date_format"));
    previousPreviousOptions.endDate = moment().day(0 + 7 - 7 - 7).format(Coconut.config.get("date_format"));
    previousPreviousPreviousOptions = _.clone(this.reportOptions);
    previousPreviousPreviousOptions.startDate = moment().day(1 - 7 - 7 - 7).format(Coconut.config.get("date_format"));
    previousPreviousPreviousOptions.endDate = moment().day(0 + 7 - 7 - 7 - 7).format(Coconut.config.get("date_format"));
    options.optionsArray = [previousPreviousPreviousOptions, previousPreviousOptions, previousOptions, currentOptions];
    $("#row-start").hide();
    $("#row-end").hide();
    return this.periodSummary(options);
  };

  ReportView.prototype.periodSummary = function(options) {
    var amountOfTime, dataValue, district, optionsArray, previousOptions, previousPreviousOptions, previousPreviousPreviousOptions, renderDataElement, renderTable, reportIndex, results;
    if (options == null) {
      options = {};
    }
    district = options.district || "ALL";
    $("#reportContents").html("<style> .data{ display:none } table.tablesorter tbody td.trend{ vertical-align: middle; } .period-2.trend i{ font-size:75% } </style> <div id='messages'></div> <div id='alerts'> <h2>Loading Data Summary...</h2> </div>");
    this.reportOptions.startDate = this.reportOptions.startDate || moment(new Date).subtract('days', 7).format("YYYY-MM-DD");
    this.reportOptions.endDate = this.reportOptions.endDate || moment(new Date).format("YYYY-MM-DD");
    $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/byCollection", {
      key: "help",
      include_docs: true,
      success: (function(_this) {
        return function(result) {
          var messages;
          messages = _(result.rows).chain().map(function(data) {
            if (!(moment(_this.reportOptions.startDate).isBefore(data.value.date) && moment(_this.reportOptions.endDate).isAfter(data.value.date))) {
              return;
            }
            return "" + data.value.date + ": " + data.value.text + "<br/>";
          }).compact().value().join("");
          if (messages !== "") {
            return $("#messages").html("<h2>Help Messages</h2> " + messages);
          }
        };
      })(this)
    });
    if (options.optionsArray) {
      optionsArray = options.optionsArray;
    } else {
      amountOfTime = moment(this.reportOptions.endDate).diff(moment(this.reportOptions.startDate));
      previousOptions = _.clone(this.reportOptions);
      previousOptions.startDate = moment(this.reportOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get("date_format"));
      previousOptions.endDate = this.reportOptions.startDate;
      previousPreviousOptions = _.clone(this.reportOptions);
      previousPreviousOptions.startDate = moment(previousOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get("date_format"));
      previousPreviousOptions.endDate = previousOptions.startDate;
      previousPreviousPreviousOptions = _.clone(this.reportOptions);
      previousPreviousPreviousOptions.startDate = moment(previousPreviousOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get("date_format"));
      previousPreviousPreviousOptions.endDate = previousPreviousOptions.startDate;
      optionsArray = [previousPreviousPreviousOptions, previousPreviousOptions, previousOptions, this.reportOptions];
    }
    results = [];
    dataValue = (function(_this) {
      return function(data) {
        if (data.disaggregated != null) {
          return data.disaggregated.length;
        } else if (data.percent != null) {
          return _this.formattedPercent(data.percent);
        } else if (data.text != null) {
          return data.text;
        }
      };
    })(this);
    renderDataElement = (function(_this) {
      return function(data) {
        var output;
        if (data.disaggregated != null) {
          output = _this.createDisaggregatableCaseGroup(data.disaggregated);
          if (data.appendPercent != null) {
            output += " (" + (_this.formattedPercent(data.appendPercent)) + ")";
          }
          return output;
        } else if (data.percent != null) {
          return _this.formattedPercent(data.percent);
        } else if (data.text != null) {
          return data.text;
        }
      };
    })(this);
    renderTable = _.after(optionsArray.length, (function(_this) {
      return function() {
        var extractNumber, index, swapColumns;
        $("#alerts").html("<h2>Data Summary</h2> <table id='alertsTable' class='tablesorter'> <tbody> " + (index = 0, _(results[0]).map(function(firstResult) {
          var element, period, sum;
          return "<tr class='" + (index % 2 === 0 ? "odd" : "even") + "'> <td>" + firstResult.title + "</td> " + (period = results.length, sum = 0, element = _.map(results, function(result) {
            sum += parseInt(dataValue(result[index]));
            return "<td class='period-" + (period -= 1) + " trend'></td> <td class='period-" + period + " data'>" + (renderDataElement(result[index])) + "</td> " + (period === 0 ? "<td class='average-for-previous-periods'>" + (sum / results.length) + "</td>" : "");
          }).join(""), index += 1, element) + " </tr>";
        }).join("")) + " </tbody> </table> <button class='toggle-trend-data'>Show trend data</button>");
        extractNumber = function(element) {
          var result;
          result = parseInt(element.text());
          if (isNaN(result)) {
            return parseInt(element.find("button").text());
          } else {
            return result;
          }
        };
        _(results.length - 1).times(function(period) {
          return _.each($(".period-" + period + ".data"), function(dataElement) {
            var current, previous;
            dataElement = $(dataElement);
            current = extractNumber(dataElement);
            previous = extractNumber(dataElement.prev().prev());
            return dataElement.prev().html(current === previous ? "-" : current > previous ? "<span class='up-arrow'>&uarr;</span>" : "<span class='down-arrow'>&darr;</span>");
          });
        });
        _.each($(".period-0.trend"), function(period0Trend) {
          period0Trend = $(period0Trend);
          if (period0Trend.prev().prev().find("span").attr("class") === period0Trend.find("span").attr("class")) {
            return period0Trend.find("span").attr("style", "color:red");
          }
        });
        $(".period-0.data").show();
        $(".period-" + (results.length - 1) + ".trend").hide();
        $(".period-1.trend").attr("style", "font-size:75%");
        $(".trend");
        $("td:contains(Period)").siblings(".trend").find("i").hide();
        $(".period-0.data").show();
        $($(".average-for-previous-periods")[0]).html("Average for previous " + (results.length - 1) + " periods");
        swapColumns = function(table, colIndex1, colIndex2) {
          var cell1, cell2, row, siblingCell1, t, _i, _len, _ref, _results;
          if (!colIndex1 < colIndex2) {
            t = colIndex1;
            colIndex1 = colIndex2;
            colIndex2 = t;
          }
          if (table && table.rows && table.insertBefore && colIndex1 !== colIndex2) {
            _ref = table.rows;
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              row = _ref[_i];
              cell1 = row.cells[colIndex1];
              cell2 = row.cells[colIndex2];
              siblingCell1 = row.cells[Number(colIndex1) + 1];
              row.insertBefore(cell1, cell2);
              _results.push(row.insertBefore(cell2, siblingCell1));
            }
            return _results;
          }
        };
        return swapColumns($("#alertsTable")[0], 8, 9);
      };
    })(this));
    reportIndex = 0;
    return _.each(optionsArray, (function(_this) {
      return function(options) {
        var anotherIndex, reports;
        anotherIndex = reportIndex;
        reportIndex++;
        reports = new Reports();
        return reports.casesAggregatedForAnalysis({
          aggregationLevel: "District",
          startDate: options.startDate,
          endDate: options.endDate,
          mostSpecificLocation: _this.mostSpecificLocationSelected(),
          success: function(data) {
            results[anotherIndex] = [
              {
                title: "Period",
                text: "" + (moment(options.startDate).format("YYYY-MM-DD")) + " -> " + (moment(options.endDate).format("YYYY-MM-DD"))
              }, {
                title: "No. of cases reported at health facilities",
                disaggregated: data.followups[district].allCases
              }, {
                title: "No. of cases reported at health facilities with complete household visits",
                disaggregated: data.followups[district].casesWithCompleteHouseholdVisit
              }, {
                title: "% of cases reported at health facilities with complete household visits",
                percent: 1 - (data.followups[district].casesWithCompleteHouseholdVisit.length / data.followups[district].allCases.length)
              }, {
                title: "Total No. of cases (including cases not reported by facilities) with complete household visits",
                disaggregated: data.followups[district].casesWithCompleteHouseholdVisit
              }, {
                title: "No. of additional household members tested",
                disaggregated: data.passiveCases[district].householdMembers
              }, {
                title: "No. of additional household members tested positive",
                disaggregated: data.passiveCases[district].passiveCases
              }, {
                title: "% of household members tested positive",
                percent: data.passiveCases[district].passiveCases.length / data.passiveCases[district].householdMembers.length
              }, {
                title: "% increase in cases found using MCN",
                percent: data.passiveCases[district].passiveCases.length / data.passiveCases[district].indexCases.length
              }, {
                title: "No. of positive cases (index & household) in persons under 5",
                disaggregated: data.ages[district].underFive
              }, {
                title: "Percent of positive cases (index & household) in persons under 5",
                percent: data.ages[district].underFive.length / data.totalPositiveCases[district].length
              }, {
                title: "Positive Cases (index & household) with at least a facility followup",
                disaggregated: data.totalPositiveCases[district]
              }, {
                title: "Positive Cases (index & household) that slept under a net night before diagnosis (percent)",
                disaggregated: data.netsAndIRS[district].sleptUnderNet,
                appendPercent: data.netsAndIRS[district].sleptUnderNet.length / data.totalPositiveCases[district].length
              }, {
                title: "Positive Cases from a household that has been sprayed within last " + Coconut.IRSThresholdInMonths + " months",
                disaggregated: data.netsAndIRS[district].recentIRS,
                appendPercent: data.netsAndIRS[district].recentIRS.length / data.totalPositiveCases[district].length
              }, {
                title: "Positive Cases (index & household) that traveled within last month (percent)",
                disaggregated: data.travel[district].travelReported,
                appendPercent: data.travel[district].travelReported.length / data.totalPositiveCases[district].length
              }
            ];
            return renderTable();
          }
        });
      };
    })(this));
  };

  ReportView.prototype.updateAnalysis = function() {
    return this.analysis($("[name=aggregationType]:checked").val());
  };

  ReportView.prototype.analysis = function(aggregationLevel) {
    var reports;
    if (aggregationLevel == null) {
      aggregationLevel = "District";
    }
    $("#reportContents").html("<div id='analysis'> <hr/> Aggregation Type: <input name='aggregationType' type='radio' " + (aggregationLevel === "District" ? "checked='true'" : "") + " value='District'>District</input> <input name='aggregationType' type='radio' " + (aggregationLevel === "Shehia" ? "checked='true'" : "") + "  value='Shehia'>Shehia</input> <hr/> <div style='font-style:italic'>Click on a column heading to sort.</div> <hr/> </div>");
    reports = new Reports();
    return reports.casesAggregatedForAnalysis({
      aggregationLevel: aggregationLevel,
      startDate: this.startDate,
      endDate: this.endDate,
      mostSpecificLocation: this.mostSpecificLocationSelected(),
      success: (function(_this) {
        return function(data) {
          var headings;
          headings = [aggregationLevel, "Cases", "Cases missing USSD Notification", "Cases missing Case Notification", "Cases with complete facility visit", "Cases without complete facility visit (but with case notification)", "Cases with complete household visit", "Cases without complete household visit (but with complete facility visit)", "% of cases with complete household visit"];
          $("#analysis").append("<h2>Cases Followed Up<small> <button onClick='$(\".details\").toggle()'>Toggle Details</button></small></h2>");
          $("#analysis").append(_this.createTable(headings, "" + (_.map(data.followups, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableCaseGroup(values.allCases)) + "</td> <td class='missingUSSD details'>" + (_this.createDisaggregatableCaseGroup(values.missingUssdNotification)) + "</td> <td>" + (_this.createDisaggregatableCaseGroup(values.missingCaseNotification)) + "</td> <td class='details'>" + (_this.createDisaggregatableCaseGroup(values.casesWithCompleteFacilityVisit)) + "</td> <td>" + (_this.createDisaggregatableCaseGroup(_.difference(values.casesWithoutCompleteFacilityVisit, values.missingCaseNotification))) + "</td> <td class='details'>" + (_this.createDisaggregatableCaseGroup(values.casesWithCompleteHouseholdVisit)) + "</td> <td>" + (_this.createDisaggregatableCaseGroup(_.difference(values.casesWithoutCompleteHouseholdVisit, values.casesWithoutCompleteFacilityVisit))) + "</td> <td>" + (_this.formattedPercent(values.casesWithCompleteHouseholdVisit.length / values.allCases.length)) + "</td> </tr>";
          }).join("")), "cases-followed-up"));
          _(["Cases with complete household visit", "Cases with complete facility visit", "Cases missing USSD Notification"]).each(function(column) {
            return $("th:contains(" + column + ")").addClass("details");
          });
          $(".details").hide();
          _.delay(function() {
            $("table.tablesorter").each(function(index, table) {
              return _($(table).find("th").length).times(function(columnNumber) {
                var columnsTds, maxIndex, maxValue;
                if (columnNumber === 0) {
                  return;
                }
                maxIndex = null;
                maxValue = 0;
                columnsTds = $(table).find("td:nth-child(" + (columnNumber + 1) + ")");
                columnsTds.each(function(index, td) {
                  var value;
                  if (index === 0) {
                    return;
                  }
                  td = $(td);
                  value = parseInt(td.text());
                  if (value > maxValue) {
                    maxValue = value;
                    return maxIndex = index;
                  }
                });
                if (maxIndex) {
                  return $(columnsTds[maxIndex]).addClass("max-value-for-column");
                }
              });
            });
            return $(".max-value-for-column button.same-cell-disaggregatable").css("color", "red");
          }, 2000);
          $("#analysis").append("<hr> <h2>Household Members</h2>");
          $("#analysis").append(_this.createTable("District, No. of cases followed up, No. of additional household members tested, No. of additional household members tested positive, % of household members tested positive, % increase in cases found using MCN".split(/, */), "" + (_.map(data.passiveCases, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableCaseGroup(values.indexCases)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.householdMembers.length, values.householdMembers)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.passiveCases.length, values.passiveCases)) + "</td> <td>" + (_this.formattedPercent(values.passiveCases.length / values.householdMembers.length)) + "</td> <td>" + (_this.formattedPercent(values.passiveCases.length / values.indexCases.length)) + "</td> </tr>";
          }).join(""))));
          $("#analysis").append("<hr> <h2>Age: <small>Includes index cases with complete household visits and positive household members</small></h2>");
          $("#analysis").append(_this.createTable("District, <5, 5<15, 15<25, >=25, Unknown, Total, %<5, %5<15, %15<25, %>=25, Unknown".split(/, */), "" + (_.map(data.ages, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.underFive.length, values.underFive)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.fiveToFifteen.length, values.fiveToFifteen)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.fifteenToTwentyFive.length, values.fifteenToTwentyFive)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.overTwentyFive.length, values.overTwentyFive)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.unknown.length, values.overTwentyFive)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(data.totalPositiveCases[location].length, data.totalPositiveCases[location])) + "</td> <td>" + (_this.formattedPercent(values.underFive.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.fiveToFifteen.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.fifteenToTwentyFive.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.overTwentyFive.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)) + "</td> </tr>";
          }).join(""))));
          $("#analysis").append("<hr> <h2>Gender: <small>Includes index cases with complete household visits and positive household members<small></h2>");
          $("#analysis").append(_this.createTable("District, Male, Female, Unknown, Total, % Male, % Female, % Unknown".split(/, */), "" + (_.map(data.gender, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.male.length, values.male)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.female.length, values.female)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.unknown.length, values.unknown)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(data.totalPositiveCases[location].length, data.totalPositiveCases[location])) + "</td> <td>" + (_this.formattedPercent(values.male.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.female.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)) + "</td> </tr>";
          }).join(""))));
          $("#analysis").append("<hr> <h2>Nets and Spraying: <small>Includes index cases with complete household visits and positive household members</small></h2>");
          $("#analysis").append(_this.createTable(("District, Positive Cases, Positive Cases (index & household) that slept under a net night before diagnosis, %, Positive Cases from a household that has been sprayed within last " + Coconut.IRSThresholdInMonths + " months, %").split(/, */), "" + (_.map(data.netsAndIRS, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableDocGroup(data.totalPositiveCases[location].length, data.totalPositiveCases[location])) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.sleptUnderNet.length, values.sleptUnderNet)) + "</td> <td>" + (_this.formattedPercent(values.sleptUnderNet.length / data.totalPositiveCases[location].length)) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.recentIRS.length, values.recentIRS)) + "</td> <td>" + (_this.formattedPercent(values.recentIRS.length / data.totalPositiveCases[location].length)) + "</td> </tr>";
          }).join(""))));
          $("#analysis").append("<hr> <h2>Travel History: <small>Includes index cases with complete household visits and positive household members</small></h2>");
          $("#analysis").append(_this.createTable("District, Positive Cases, Positive Cases (index & household) that traveled within last month, %".split(/, */), "" + (_.map(data.travel, function(values, location) {
            return "<tr> <td>" + location + "</td> <td>" + (_this.createDisaggregatableDocGroup(data.totalPositiveCases[location].length, data.totalPositiveCases[location])) + "</td> <td>" + (_this.createDisaggregatableDocGroup(values.travelReported.length, values.travelReported)) + "</td> <td>" + (_this.formattedPercent(values.travelReported.length / data.totalPositiveCases[location].length)) + "</td> </tr>";
          }).join(""))));
          return $("#analysis table").tablesorter({
            widgets: ['zebra'],
            sortList: [[0, 0]],
            textExtraction: function(node) {
              var sortValue;
              sortValue = $(node).find(".sort-value").text();
              if (sortValue !== "") {
                return sortValue;
              } else {
                if ($(node).text() === "--") {
                  return "-1";
                } else {
                  return $(node).text();
                }
              }
            }
          });
        };
      })(this)
    });
  };

  ReportView.prototype.formattedPercent = function(number) {
    var percent;
    percent = (number * 100).toFixed(0);
    if (isNaN(percent)) {
      return "--";
    } else {
      return "" + percent + "%";
    }
  };

  ReportView.prototype.pilotNotifications = function() {
    var comparisonData, renderComparisonData;
    $("#reportContents").html("<h2>Comparison of Case Notifications from USSD vs Pilot at all pilot sites</h2> <div style='background-color:#FFCCCC'> Pink entires are unmatched. If they cannot be matched (due to spelling differences for instance) recommend calling facility to find out why the case was not sent with both systems. </div> <table id='comparison'> <thead> <th>Facility</th> <th>Patient Name</th> <th>USSD Case ID</th> <th>Pilot Case ID</th> <th>USSD Notification Time</th> <th>Pilot Notification Time</th> <th>Time Difference</th> <th class='sort'>Sorting</th> <th>Source</th> </thead> <tbody></tbody> </table> <h2>Pilot Weekly Reports</h2> <table id='weekly_report'> <thead></thead> <tbody></tbody> </table> <h2>Pilot New Cases Details</h2> <button onClick='$(\"#new_case\").toggle()'>Show/Hide</button> <table style='display:none' id='new_case'> <thead></thead> <tbody></tbody> </table>");
    comparisonData = {};
    renderComparisonData = _.after(2, function() {
      $("#comparison tbody").html(_.map(comparisonData, function(data, facilityWithPatientName) {
        return "<tr> <td>" + data.facility + "</td> <td>" + (data.name || "-") + "</td> <td>" + (data.USSDcaseId || "-") + "</td> <td>" + (data.pilotCaseId || "-") + "</td> <td>" + (data["USSD Notification Time"] || "-") + "</td> <td>" + (data["Pilot Notification Time"] || "-") + "</td> <td class='difference'> " + (data["Pilot Notification Time"] && data["USSD Notification Time"] ? moment(data["USSD Notification Time"]).from(moment(data["Pilot Notification Time"]), true) : "-") + " </td> <td style='display:none' class='sort'>" + (data["Pilot Notification Time"] || "") + (data["USSD Notification Time"] || "") + "</td> <td>" + (data.source || "-") + "</td> </tr>";
      }));
      $(".sort").hide();
      $("#comparison").dataTable({
        aaSorting: [[0, "asc"], [6, "desc"], [5, "desc"]],
        iDisplayLength: 50
      });
      return $(".difference:contains(-)").parent().attr("style", "background-color: #FFCCCC");
    });
    this.getCases({
      success: (function(_this) {
        return function(results) {
          var pilotFacilities;
          pilotFacilities = ["CHUKWANI", "SELEM", "BUBUBU JESHINI", "UZINI", "MWERA", "MIWANI", "CHIMBA", "TUMBE", "PANDANI", "TUNGAMAA"];
          _.each(results, function(caseResult) {
            var facilityWithPatientName;
            if (_(pilotFacilities).contains(caseResult.facility())) {
              facilityWithPatientName = "" + (caseResult.facility()) + "-" + (caseResult.indexCasePatientName());
              if (comparisonData[facilityWithPatientName] == null) {
                comparisonData[facilityWithPatientName] = {};
              }
              comparisonData[facilityWithPatientName].name = caseResult.indexCasePatientName();
              comparisonData[facilityWithPatientName].USSDcaseId = caseResult.MalariaCaseID();
              comparisonData[facilityWithPatientName].facility = caseResult.facility();
              if (caseResult["USSD Notification"] != null) {
                return comparisonData[facilityWithPatientName]["USSD Notification Time"] = caseResult["USSD Notification"].date;
              }
            }
          });
          return renderComparisonData();
        };
      })(this)
    });
    $("tr.location").hide();
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/pilotNotifications", {
      startkey: this.startDate,
      endkey: moment(this.endDate).endOf("day").format("YYYY-MM-DD HH:mm:ss"),
      include_docs: true,
      success: (function(_this) {
        return function(results) {
          var tableData;
          tableData = {
            new_case: "",
            weekly_report: ""
          };
          _(results.rows).each(function(row) {
            var facilityWithPatientName, keys, type;
            facilityWithPatientName = "" + row.doc.hf + "-" + row.doc.name;
            if (comparisonData[facilityWithPatientName] == null) {
              comparisonData[facilityWithPatientName] = {};
            }
            comparisonData[facilityWithPatientName].name = row.doc.name;
            comparisonData[facilityWithPatientName].pilotCaseId = row.doc.caseid;
            comparisonData[facilityWithPatientName].facility = row.doc.hf;
            comparisonData[facilityWithPatientName]["Pilot Notification Time"] = row.doc.date;
            comparisonData[facilityWithPatientName].source = row.doc.source;
            keys = _(_(row.doc).keys()).without("_id", "_rev", "type");
            type = row.doc.type.replace(/\s/, "_");
            if ($("#" + type + " thead").html() === "") {
              $("#" + type + " thead").html(_(keys).map(function(key) {
                return "<th>" + key + "</th>";
              }).join(""));
            }
            return tableData[type] += "<tr> " + (_(keys).map(function(key) {
              return "<td>" + row.doc[key] + "</td>";
            }).join("")) + " </tr>";
          });
          _(_(tableData).keys()).each(function(key) {
            return $("#" + key + " tbody").html(tableData[key]);
          });
          return renderComparisonData();
        };
      })(this)
    });
  };

  ReportView.prototype.dashboard = function() {
    var tableColumns;
    $("tr.location").hide();
    $("#reportContents").html("<!-- Reported/Facility Followup/Household Followup/#Tested/ (Show for Same period last year) For completed cases, average time between notification and household followup Last seven days Last 30 days Last 365 days Current month Current year Total --> <h2>Alerts</h2> <div id='alerts'></div> <h1> Cases </h2> For the selected period:<br/> <table> <tr> <td>Cases Reported at Facility</td> <td id='Cases-Reported-at-Facility'></td> </tr> <tr> <td>Additional People Tested</td> <td id='Additional-People-Tested'></td> </tr> <tr> <td>Additional People Tested Positive</td> <td id='Additional-People-Tested-Positive'></td> </tr> </table> <br/> Click on a button for more details about the case. Pink buttons are for <span style='background-color:pink'> positive malaria results.</span> <table class='summary tablesorter'> <thead><tr> </tr></thead> <tbody> </tbody> </table> <style> table a, table a:link, table a:visited {color: blue; font-size: 150%} </style>");
    tableColumns = ["Case ID", "Diagnosis Date", "Health Facility District", "USSD Notification"];
    Coconut.questions.fetch({
      success: function() {
        tableColumns = tableColumns.concat(Coconut.questions.map(function(question) {
          return question.label();
        }));
        return _.each(tableColumns, function(text) {
          return $("table.summary thead tr").append("<th>" + text + " (<span id='th-" + (text.replace(/\s/, "")) + "-count'></span>)</th>");
        });
      }
    });
    return this.getCases({
      success: (function(_this) {
        return function(cases) {
          var districtsWithFollowup;
          _.each(cases, function(malariaCase) {
            return $("table.summary tbody").append("<tr class='followed-up-" + (malariaCase.followedUp()) + "' id='case-" + malariaCase.caseID + "'> <td class='CaseID'> <a href='#show/case/" + malariaCase.caseID + "'><button>" + malariaCase.caseID + "</button></a> </td> <td class='IndexCaseDiagnosisDate'> " + (malariaCase.indexCaseDiagnosisDate()) + " </td> <td class='HealthFacilityDistrict'> " + (malariaCase["USSD Notification"] != null ? FacilityHierarchy.getDistrict(malariaCase["USSD Notification"].hf) : "") + " </td> <td class='USSDNotification'> " + (_this.createDashboardLinkForResult(malariaCase, "USSD Notification", "<img src='images/ussd.png'/>")) + " </td> <td class='CaseNotification'> " + (_this.createDashboardLinkForResult(malariaCase, "Case Notification", "<img src='images/caseNotification.png'/>")) + " </td> <td class='Facility'> " + (_this.createDashboardLinkForResult(malariaCase, "Facility", "<img src='images/facility.png'/>")) + " </td> <td class='Household'> " + (_this.createDashboardLinkForResult(malariaCase, "Household", "<img src='images/household.png'/>")) + " </td> <td class='HouseholdMembers'> " + (_.map(malariaCase["Household Members"], function(householdMember) {
              var buttonText;
              buttonText = "<img src='images/householdMember.png'/>";
              if (householdMember.complete == null) {
                if (!householdMember.complete) {
                  buttonText = buttonText.replace(".png", "Incomplete.png");
                }
              }
              return _this.createCaseLink({
                caseID: malariaCase.caseID,
                docId: householdMember._id,
                buttonClass: (householdMember.MalariaTestResult != null) && (householdMember.MalariaTestResult === "PF" || householdMember.MalariaTestResult === "Mixed") ? "malaria-positive" : "",
                buttonText: buttonText
              });
            }).join("")) + " </td> </tr>");
          });
          _.each(tableColumns, function(text) {
            var columnId;
            columnId = text.replace(/\s/, "");
            return $("#th-" + columnId + "-count").html($("td." + columnId + " button").length);
          });
          $("#Cases-Reported-at-Facility").html($("td.CaseID button").length);
          $("#Additional-People-Tested").html($("td.HouseholdMembers button").length);
          $("#Additional-People-Tested-Positive").html($("td.HouseholdMembers button.malaria-positive").length);
          if ($("table.summary tr").length > 1) {
            $("table.summary").tablesorter({
              widgets: ['zebra'],
              sortList: [[1, 1]]
            });
          }
          districtsWithFollowup = {};
          _.each($("table.summary tr"), function(row) {
            row = $(row);
            if (row.find("td.USSDNotification button").length > 0) {
              if (row.find("td.CaseNotification button").length === 0) {
                if (moment().diff(row.find("td.IndexCaseDiagnosisDate").html(), "days") > 2) {
                  if (districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()] == null) {
                    districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()] = 0;
                  }
                  return districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()] += 1;
                }
              }
            }
          });
          return $("#alerts").append("<style> #alerts,table.alerts{ font-size: 80% } </style> The following districts have USSD Notifications that have not been followed up after two days. Recommendation call the DMSO: <table class='alerts'> <thead> <tr> <th>District</th><th>Number of cases</th> </tr> </thead> <tbody> " + (_.map(districtsWithFollowup, function(numberOfCases, district) {
            return "<tr> <td>" + district + "</td> <td>" + numberOfCases + "</td> </tr>";
          }).join("")) + " </tbody> </table>");
        };
      })(this)
    });
  };

  ReportView.prototype.createDashboardLinkForResult = function(malariaCase, resultType, buttonText) {
    if (buttonText == null) {
      buttonText = "";
    }
    if (malariaCase[resultType] != null) {
      if (malariaCase[resultType].complete == null) {
        if (!malariaCase[resultType].complete) {
          if (resultType !== "USSD Notification") {
            buttonText = buttonText.replace(".png", "Incomplete.png");
          }
        }
      }
      return this.createCaseLink({
        caseID: malariaCase.caseID,
        docId: malariaCase[resultType]._id,
        buttonText: buttonText
      });
    } else {
      return "";
    }
  };

  ReportView.prototype.createCaseLink = function(options) {
    if (options.buttonText == null) {
      options.buttonText = options.caseID;
    }
    return "<a href='#show/case/" + options.caseID + (options.docId != null ? "/" + options.docId : "") + "'><button class='" + options.buttonClass + "'>" + options.buttonText + "</button></a>";
  };

  ReportView.prototype.createCasesLinks = function(cases) {
    return _.map(cases, (function(_this) {
      return function(malariaCase) {
        return _this.createCaseLink({
          caseID: malariaCase.caseID
        });
      };
    })(this)).join("");
  };

  ReportView.prototype.createDisaggregatableCaseGroup = function(cases, text) {
    if (text == null) {
      text = cases.length;
    }
    return "<button class='sort-value same-cell-disaggregatable'>" + text + "</button> <div class='cases' style='display:none'> " + (this.createCasesLinks(cases)) + " </div>";
  };

  ReportView.prototype.createDocLinks = function(docs) {
    return _.map(docs, (function(_this) {
      return function(doc) {
        return _this.createCaseLink({
          caseID: doc.MalariaCaseID,
          docId: doc._id
        });
      };
    })(this)).join("");
  };

  ReportView.prototype.createDisaggregatableDocGroup = function(text, docs) {
    return "<button class='sort-value same-cell-disaggregatable'>" + text + "</button> <div class='cases' style='display:none'> " + (this.createDocLinks(docs)) + " </div>";
  };

  ReportView.prototype.systemErrors = function() {
    this.renderAlertStructure(["system_errors"]);
    return Reports.systemErrors({
      success: (function(_this) {
        return function(errorsByType) {
          var alerts;
          if (_(errorsByType).isEmpty()) {
            $("#system_errors").append("No system errors.");
          } else {
            alerts = true;
            $("#system_errors").append("The following system errors have occurred in the last 2 days: <table style='border:1px solid black' class='system-errors'> <thead> <tr> <th>Time of most recent error</th> <th>Message</th> <th>Number of errors of this type in last 24 hours</th> <th>Source</th> </tr> </thead> <tbody> " + (_.map(errorsByType, function(errorData, errorMessage) {
              return "<tr> <td>" + errorData["Most Recent"] + "</td> <td>" + errorMessage + "</td> <td>" + errorData.count + "</td> <td>" + errorData["Source"] + "</td> </tr>";
            }).join("")) + " </tbody> </table>");
          }
          return _this.afterFinished();
        };
      })(this)
    });
  };

  ReportView.prototype.casesWithoutCompleteHouseholdVisit = function() {
    this.renderAlertStructure(["not_followed_up"]);
    return Reports.casesWithoutCompleteHouseholdVisit({
      startDate: this.startDate,
      endDate: this.endDate,
      mostSpecificLocation: this.mostSpecificLocationSelected(),
      success: (function(_this) {
        return function(casesWithoutCompleteHouseholdVisit) {
          var alerts;
          if (casesWithoutCompleteHouseholdVisit.length === 0) {
            $("#not_followed_up").append("All cases between " + _this.startDate + " and " + _this.endDate + " have had a complete household visit within two days.");
          } else {
            alerts = true;
            $("#not_followed_up").append("The following districts have USSD Notifications that occurred between " + _this.startDate + " and " + _this.endDate + " that have not had a completed household visit after two days. Recommendation call the DMSO: <table  style='border:1px solid black' class='alerts'> <thead> <tr> <th>Facility</th> <th>District</th> <th>Officer</th> <th>Phone number</th> </tr> </thead> <tbody> " + (_.map(casesWithoutCompleteHouseholdVisit, function(malariaCase) {
              var district, user;
              district = malariaCase.district() || "UNKNOWN";
              if (district === "ALL" || district === "UNKNOWN") {
                return "";
              }
              user = Users.where({
                district: district
              });
              if (user.length) {
                user = user[0];
              }
              return "<tr> <td>" + (malariaCase.facility()) + "</td> <td>" + (district.titleize()) + "</td> <td>" + (typeof user.get === "function" ? user.get("name") : void 0) + "</td> <td>" + (typeof user.username === "function" ? user.username() : void 0) + "</td> </tr>";
            }).join("")) + " </tbody> </table>");
          }
          return _this.afterFinished();
        };
      })(this)
    });
  };

  ReportView.prototype.casesWithUnknownDistricts = function() {
    this.renderAlertStructure(["unknown_districts"]);
    return Reports.unknownDistricts({
      startDate: this.startDate,
      endDate: this.endDate,
      mostSpecificLocation: this.mostSpecificLocationSelected(),
      success: (function(_this) {
        return function(casesWithoutCompleteHouseholdVisitWithUnknownDistrict) {
          var alerts;
          if (casesWithoutCompleteHouseholdVisitWithUnknownDistrict.length === 0) {
            $("#unknown_districts").append("All cases between " + _this.startDate + " and " + _this.endDate + " that have not been followed up have shehias with known districts");
          } else {
            alerts = true;
            $("#unknown_districts").append("The following cases have not been followed up and have shehias with unknown districts (for period " + _this.startDate + " to " + _this.endDate + ". These may be traveling patients or incorrectly spelled shehias. Please contact an administrator if the problem can be resolved by fixing the spelling. <table style='border:1px solid black' class='unknown-districts'> <thead> <tr> <th>Health facility</th> <th>Shehia</th> <th>Case ID</th> </tr> </thead> <tbody> " + (_.map(casesWithoutCompleteHouseholdVisitWithUnknownDistrict, function(caseNotFollowedUpWithUnknownDistrict) {
              return "<tr> <td>" + (caseNotFollowedUpWithUnknownDistrict["USSD Notification"].hf.titleize()) + "</td> <td>" + (caseNotFollowedUpWithUnknownDistrict.shehia().titleize()) + "</td> <td><a href='#show/case/" + caseNotFollowedUpWithUnknownDistrict.caseID + "'>" + caseNotFollowedUpWithUnknownDistrict.caseID + "</a></td> </tr>";
            }).join("")) + " </tbody> </table>");
          }
          return afterFinished();
        };
      })(this)
    });
  };

  ReportView.prototype.tabletSync = function(options) {
    var endDate, startDate;
    startDate = moment(this.startDate);
    endDate = moment(this.endDate).endOf("day");
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/syncLogByDate", {
      startkey: this.startDate,
      endkey: moment(this.endDate).endOf("day").format("YYYY-MM-DD HH:mm:ss"),
      include_docs: false,
      success: (function(_this) {
        return function(syncLogResult) {
          var users;
          users = new UserCollection();
          return users.fetch({
            error: function(error) {
              return console.error("Couldn't fetch UserCollection");
            },
            success: function() {
              var initializeEntryForUser, numberOfDays, numberOfSyncsPerDayByUser;
              numberOfDays = endDate.diff(startDate, 'days') + 1;
              initializeEntryForUser = function(user) {
                numberOfSyncsPerDayByUser[user] = {};
                return _(numberOfDays).times(function(dayNumber) {
                  return numberOfSyncsPerDayByUser[user][moment(_this.startDate).add(dayNumber, "days").format("YYYY-MM-DD")] = 0;
                });
              };
              numberOfSyncsPerDayByUser = {};
              _(users.models).each(function(user) {
                if ((user.district() != null) && !(user.inactive === "true" || user.inactive)) {
                  console.log(user.get("name"));
                }
                if ((user.district() != null) && !(user.inactive === "true" || user.inactive)) {
                  console.log(user);
                }
                if ((user.district() != null) && !(user.get("inactive") === "true" || user.get("inactive"))) {
                  return initializeEntryForUser(user.get("_id"));
                }
              });
              _(syncLogResult.rows).each(function(syncEntry) {
                if (numberOfSyncsPerDayByUser[syncEntry.value] == null) {
                  initializeEntryForUser(syncEntry.value);
                }
                return numberOfSyncsPerDayByUser[syncEntry.value][moment(syncEntry.key).format("YYYY-MM-DD")] += 1;
              });
              console.table(numberOfSyncsPerDayByUser);
              $("#reportContents").html("<br/> <br/> Number of Syncs Performed by User<br/> <br/> <table id='syncLogTable'> <thead> <th>District</th> <th>Name</th> " + (_(numberOfDays).times(function(dayNumber) {
                return "<th>" + (moment(_this.startDate).add(dayNumber, "days").format("YYYY-MM-DD")) + "</th>";
              }).join("")) + " </thead> <tbody> " + (_(numberOfSyncsPerDayByUser).map(function(data, user) {
                if (users.get(user) == null) {
                  console.error("Could not find user: " + user);
                  return;
                }
                return "<tr> <td>" + (users.get(user).district()) + "</td> <td>" + (users.get(user).get("name")) + "</td> " + (_(numberOfSyncsPerDayByUser[user]).map(function(value, day) {
                  var color;
                  color = value === 0 ? "#FFCCFF" : value <= 5 ? "#CCFFCC" : "#8AFF8A";
                  return "<td style='text-align:center; background-color: " + color + "'>" + value + "</td>";
                }).join("")) + " </tr>";
              }).join("")) + " </tbody> </table>");
              $("#syncLogTable").dataTable({
                aaSorting: [[0, "asc"]],
                iDisplayLength: 50
              });
              $("#syncLogTable_length").hide();
              $("#syncLogTable_info").hide();
              return $("#syncLogTable_paginate").hide();
            }
          });
        };
      })(this)
    });
  };

  ReportView.prototype.weeklyReports = function(options) {
    var endDate, endWeek, endYear, startDate, startWeek, startYear;
    $("#row-region").hide();
    startDate = moment(this.startDate);
    startYear = startDate.format("YYYY");
    startWeek = startDate.format("ww");
    endDate = moment(this.endDate).endOf("day");
    endYear = endDate.format("YYYY");
    endWeek = endDate.format("ww");
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/weeklyDataBySubmitDate", {
      startkey: [startYear, startWeek],
      endkey: [endYear, endWeek],
      include_docs: true,
      success: (function(_this) {
        return function(results) {
          $("#reportContents").html("<style> td.number{ text-align: center; vertical-align: middle; } </style> <br/> <br/> Weekly Reports<br/> <br/> <table class='tablesorter' id='syncLogTable'> <thead> " + (_.map(results.rows[0].doc, function(value, key) {
            console.log(key);
            if (_(["_id", "_rev", "source", "type"]).contains(key)) {
              return;
            }
            return "<th>" + key + "</th>";
          }).join("")) + " </thead> <tbody> " + (_(results.rows).map(function(row) {
            return "<tr> " + (_(row.doc).map(function(value, key) {
              if (_(["_id", "_rev", "source", "type"]).contains(key)) {
                return;
              }
              return "<td>" + value + "</td>";
            }).join("")) + " </tr>";
          }).join("")) + " </tbody> </table>");
          return $("#syncLogTable").dataTable({
            aaSorting: [[0, "desc"], [1, "desc"], [2, "desc"]],
            iDisplayLength: 50
          });
        };
      })(this)
    });
  };

  return ReportView;

})(Backbone.View);
