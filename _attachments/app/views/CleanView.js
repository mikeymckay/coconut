var CleanView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

CleanView = (function(_super) {
  __extends(CleanView, _super);

  function CleanView() {
    this.render = __bind(this.render, this);
    this.removeRedundantResultsConfirm = __bind(this.removeRedundantResultsConfirm, this);
    this.removeRedundantResults = __bind(this.removeRedundantResults, this);
    return CleanView.__super__.constructor.apply(this, arguments);
  }

  CleanView.prototype.initialize = function() {};

  CleanView.prototype.el = '#content';

  CleanView.prototype.events = {
    "click #update": "update",
    "click #removeRedundantResults": "removeRedundantResults",
    "click #removeRedundantResultsConfirm": "removeRedundantResultsConfirm",
    "click .resolveLostToFollowup": "resolveLostToFollowup",
    "click #toggleResultsMarkedAsLostToFollowup": "toggleResultsMarkedAsLostToFollowup",
    "click .resolve": "showResolveOptions"
  };

  CleanView.prototype.showResolveOptions = function(event) {
    $(event.target).hide();
    return $(event.target).siblings().show();
  };

  CleanView.prototype.toggleResultsMarkedAsLostToFollowup = function() {
    return $("td:contains(Marked As Lost To Followup)").parent().toggle();
  };

  CleanView.prototype.resolveLostToFollowup = function(event) {
    var resolutionText, result, row;
    row = $(event.target).closest("tr");
    resolutionText = $(event.target).text();
    if (resolutionText === "Household followed up for another index case") {
      resolutionText = "" + resolutionText + ": " + (prompt("Case ID for other household member that was followed up"));
    }
    result = new Result({
      _id: row.attr("data-resultId")
    });
    return result.fetch({
      success: function() {
        var dataToSave;
        dataToSave = result.question() === "Facility" ? {
          Hassomeonefromthesamehouseholdrecentlytestedpositiveatahealthfacility: "Yes",
          CaseIDforotherhouseholdmemberthattestedpositiveatahealthfacility: caseIdReference,
          LostToFollowup: resolutionText
        } : {
          LostToFollowup: resolutionText
        };
        return result.save(dataToSave, {
          success: function() {
            return row.hide();
          }
        });
      }
    });
  };

  CleanView.prototype.update = function() {
    return Coconut.router.navigate("clean/" + ($('#start').val()) + "/" + ($('#end').val()), true);
  };

  CleanView.prototype.removeRedundantResults = function() {
    var resultsToRemove;
    resultsToRemove = _.chain(this.redundantDataHash).values().flatten().value();
    $("#missingResults").hide();
    return $("#missingResults").before("Removing " + resultsToRemove.length + ". <button type='button' id='removeRedundantResultsConfirm'>Confirm</button>");
  };

  CleanView.prototype.removeRedundantResultsConfirm = function() {
    var resultsToRemove;
    resultsToRemove = _.chain(this.redundantDataHash).values().flatten().value();
    return $.couch.db(Coconut.config.database_name()).allDocs({
      keys: resultsToRemove,
      include_docs: true,
      success: function(result) {
        console.log(_.pluck(result.rows, "doc"));
        return $.couch.db(Coconut.config.database_name()).bulkRemove({
          docs: _.pluck(result.rows, "doc")
        });
      }
    });
  };

  CleanView.prototype.render = function(args) {
    var headers, problemCases, rc, reports;
    this.args = args;
    if (this.args === "undo") {
      if (User.currentUser.username() !== "admin") {
        throw "Must be admin";
      }
      rc = new ResultCollection();
      rc.fetch({
        include_docs: true,
        success: function() {
          var changed_results;
          changed_results = rc.filter(function(result) {
            return (result.get("user") === "reports") && (result.get("question") === "Household Members");
          });
          return _.each(changed_results, function(result) {
            return $.couch.db(Coconut.config.database_name()).openDoc(result.id, {
              revs_info: true
            }, {
              success: function(doc) {
                return $.couch.db(Coconut.config.database_name()).openDoc(result.id, {
                  rev: doc._revs_info[1].rev
                }, {
                  success: function(previousDoc) {
                    var newDoc;
                    newDoc = previousDoc;
                    newDoc._rev = doc._rev;
                    return result.save(newDoc);
                  }
                });
              }
            });
          });
        }
      });
      return;
    }
    this.total = 0;
    headers = "Result (click to edit),Case ID,Patient Name,Health Facility,Issues,Creation Date,Last Modified Date,Complete,User,Lost to Followup".split(/, */);
    this.$el.html("Start Date: <input id='start' class='date' type='text' value='" + this.startDate + "'/> End Date: <input id='end' class='date' type='text' value='" + this.endDate + "'/> <button id='update' type='button'>Update</button> <h1 id='header'>The following data requires cleaning or has not yet been followed up</h1> <div id='missingResults'> <table class='tablesorter'> <thead> " + (_.map(headers, function(header) {
      return "<th>" + header + "</th>";
    }).join("")) + " </thead> <tbody/> </table> </div> <!-- <div id='duplicates'> <table> <thead> <th>Duplicates</th> </thead> <tbody> </table> </div> <h2>Dates (<span id='total'></span>)</h2> <a href='#clean/apply_dates'<button>Apply Recommended Date Fixes</button></a> <div id='dates'> <table> </table> </div> <h2>CaseIDS (<span id='total'></span>)</h2> <a href='#clean/apply_caseIDs'<button>Apply Recommended CaseID Fixes</button></a> <div id='caseIDs'> <table> <thead> <th>Current</th> <th>Recommendation</th> </thead> <tbody> </table> </div> -->");
    $("thead th").append("<br/><input style='width:50px;font-size:80%;'></input>");
    $("thead th input").keyup((function(_this) {
      return function(event) {
        return _this.dataTable.fnFilter($(event.target).val(), $("thead th input").index(event.target));
      };
    })(this));
    problemCases = {};
    reports = new Reports();
    return reports.casesAggregatedForAnalysis({
      startDate: this.startDate,
      endDate: this.endDate,
      mostSpecificLocation: {
        name: "ALL"
      },
      success: (function(_this) {
        return function(data) {
          var lostToFollowup, users;
          _.each("missingCaseNotification,missingUssdNotification,casesNotFollowedUp".split(/,/), function(issue) {
            return _.each(data.followupsByDistrict.ALL[issue], function(malariaCase) {
              if (problemCases[malariaCase.caseID] == null) {
                problemCases[malariaCase.caseID] = {};
                problemCases[malariaCase.caseID]["problems"] = [];
                problemCases[malariaCase.caseID]["malariaCase"] = malariaCase;
              }
              return problemCases[malariaCase.caseID]["problems"].push(issue);
            });
          });
          _this.redundantDataHash = {};
          _this.extraIncomplete = {};
          $("#missingResults tbody").append(_.map(problemCases, function(data, caseID) {
            var res;
            return "" + (res = _.map(data.malariaCase.caseResults, function(result) {
              var caseIDLink, complete, createdAt, dataHash, facility, lastModifiedAt, name, question, redundant, redundantData, user, _ref;
              dataHash = b64_sha1(JSON.stringify(_.omit(result, "_id", "_rev", "createdAt", "lastModifiedAt")));
              redundantData = _this.redundantDataHash[dataHash] != null ? (_this.redundantDataHash[dataHash].push(result._id), "redundant") : (_this.redundantDataHash[dataHash] = [], '-');
              _ref = (function() {
                switch (result["question"]) {
                  case "Facility":
                    return ["<a target='_blank' href='#edit/result/" + result._id + "'>" + result.question + "</a>", "<a target='_blank' href='#show/case/" + result.MalariaCaseID + "'>" + result.MalariaCaseID + "</a>", "" + result["FirstName"] + " " + result["LastName"], result["FacilityName"], result["createdAt"], result["lastModifiedAt"], result["complete"], dataHash, redundantData, result["user"]];
                  case "Case Notification":
                    return ["<a target='_blank' href='#edit/result/" + result._id + "'>" + result.question + "</a>", "<a target='_blank' href='#show/case/" + result.MalariaCaseID + "'>" + result.MalariaCaseID + "</a>", result["Name"], result["FacilityName"], result["createdAt"], result["lastModifiedAt"], result["complete"], dataHash, redundantData, result["user"]];
                  case "Household":
                    console.log(result);
                    return ["<a target='_blank' href='#edit/result/" + result._id + "'>" + result.question + "</a>", "<a target='_blank' href='#show/case/" + result.MalariaCaseID + "'>" + result.MalariaCaseID + "</a>", "", "", result["createdAt"], result["lastModifiedAt"], result["complete"], dataHash, redundantData, result["user"]];
                  default:
                    if (result.hf != null) {
                      return ["<a target='_blank' href='#show/result/" + result._id + "'>USSD Notification</a>", "<a target='_blank' href='#show/case/" + result.caseid + "'>" + result.caseid + "</a>", result["name"], result["hf"], result["date"], result["date"], result["SMSSent"], dataHash, redundantData, "USSD"];
                    } else {
                      return [null, null, null, null];
                    }
                }
              })(), question = _ref[0], caseIDLink = _ref[1], name = _ref[2], facility = _ref[3], createdAt = _ref[4], lastModifiedAt = _ref[5], complete = _ref[6], dataHash = _ref[7], redundant = _ref[8], user = _ref[9];
              if (question === null) {
                return "";
              }
              return "<tr data-resultId='" + result._id + "'> <td>" + question + "</td> <td>" + caseIDLink + "</td> <td>" + name + "</td> <td>" + facility + "</td> <td>" + (_(data.problems).without("missingCaseNotification", "casesNotFollowedUp").concat(data.malariaCase.issuesRequiringCleaning()).join(", ")) + "</td> <td>" + createdAt + "</td> <td>" + lastModifiedAt + "</td> <td>" + complete + "</td> <!-- <td>" + dataHash + "</td> <td>" + redundant + "</td> --> <td>" + user + "</td> <td> " + (result["LostToFollowup"] != null ? result["LostToFollowup"] : ("<button class='resolve' type='button'>Resolve</button> <button style='display:none' type='button'><a target='_blank' href='#delete/result/" + result._id + "'>Delete</a></button>") + _.map("Unreachable,Refused,Household followed up for another index case".split(/,/), function(reason) {
                return "<button style='display:none' class='resolveLostToFollowup' type='button'><small>" + reason + "</small></button>";
              }).join("")) + " </td> </tr>";
            }).join(""));
          }).join(""));
          lostToFollowup = $("td:contains(Marked As Lost To Followup)");
          lostToFollowup.parent().hide();
          users = new UserCollection();
          users.fetch({
            success: function() {
              users.each(function(user) {
                return $("td:contains(" + (user.username()) + ")").html("" + (user.get("name")) + ": " + (user.username()));
              });
              _this.dataTable = $("#missingResults table").dataTable();
              return $('th').unbind('click.DT');
            }
          });
          if (!_.isEmpty(_this.redundantDataHash)) {
            $("#missingResults table").before("<button id='removeRedundantResults' type='button'>Remove " + (_.chain(_this.redundantDataHash).values().flatten().value().length) + " redundant results</button>");
          }
          if (lostToFollowup.length > 0) {
            return $("#missingResults table").before("<button id='toggleResultsMarkedAsLostToFollowup' type='button'>Toggle Display of results marked As Lost To Followup</button>");
          }
        };
      })(this)
    });
  };

  CleanView.prototype.searchForDuplicates = function() {
    var dupes, found;
    dupes = [];
    found = {};
    console.log("Downloading all notifications");
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/notifications", {
      include_docs: true,
      success: function(result) {
        var dupeTargets, i;
        console.log("Searching " + result.rows.length + " results");
        dupeTargets = ["WAMBA,SALEH", "WAMBA,MUHD OMI", "WAMBAA,KHAMIS ALI", "WAMBAA,KHALIDI MASOUD", "JUNGANI,HIDAYA MKUBWA", "CHANGAWENI,IBRAHIM KASIM", "WAMBAA,WAHIDA MBAROUK", "WAMBAA,KADIRU SULEIMAN", "SHUMBA MJIN,SHARIF", "MIZINGANI,SAADA MUSSA", "CHANGAWENI,HALIMA BAKAR", "WAMBAA,ALI JUMA KHAMIS", "WAMBAA,SLEIMAN KHAMIS", "MBUGUANI,AMINA ALI HAJI", "WAMBAA,SLEIMAN USSI", "SHAURIMOYO,KHAIRAT HAJI KHAMIS", "CHANGAWENI,MUSSA KASSIM", "KIPAPO,HAITHAM HAJI", "MICHENZANI,BIKOMBO HAKIMU", "MICHENZANI,ARAFA KHATIB", "CHANGAWENI,SAMIRA MKUBWA", "MICHENZANI,SALEH ABDALLA", "WAMBAA,MUHD OMI", "KUNGUNI,ZULEKHA", "KUNGUNI,RAYA", "KUNGUNI,SALAMA", "KUNGUNI,TALIB", "AMANI,ZAINAB HAROUB", "SHAKANI,JANET", "SHAKANI,PAULINA", "NDAGONI,ASHA", "KINUNI,ALI ABDALLA", "NYERERE,JUMA", "KUNGUNI,AWENA", "KUNGUNI,INAT", "KUNGUNI,ALI", "KIEMBE SAMAKI,NEILA SALUM ABDALLA", "KIEMBE SAMAKI,NEILA", "TONDOONI,SAID", "MSEWENI,ZAHARANI", "KUNGUNI,FAHD", "KUNGUNI,ALI", "KUNGUNI,YASIR", "CHONGA,FATMA", "KIUNGONI,ABDUL", "DONGE  MCHANGANI,KHADIJA", "KIPANGE,IHIDINA", "CHEJU,KHAMIS", "UTAANI,RAHMA", "TUMBE MASHARIKI,OMAR SAID OMAR", "MAGOGONI,FATMA  SLEIMAN", "NDAGONI,ARKAM", "MWANAKWEREKWE,MUKTAR MOHD", "TUNGUU,FADHIL", "KISAUNI,FERUZ", "NDAGONI,NAOMBA", "TUMBE MASHARIKI,RUMAIZA ALI KHAMIS", "KARANGE,SALUM", "MNYIMBI,HAMAD", "MNYIMBI,FATUMA", "MCHANGANI,MOHD", "M/KIDATU,MWANAISHA SALEH ALI", "KONDE,BIMKASI", "TUMBE MASHARIKI,ALI SHAURI HAJI", "KARANGE,MUKRIM", "MTMBILE,LAILATI", "MTAMBILE,YUSSUF", "MTAMBILE,MACHANO", "VIJIBWENI,IBAHIM", "MTAMBILE,HAWA", "MTAMBILE,ZUHURA", "MELI NNE,RASULI", "NGAMBWA,MKWABI", "DONGE  MCHANGANI,MAKAME", "OLE,OMI", "MKOKOTONI,SEMENI", "SHAKANI,HALIMA", "SHAKANI,FAUZIA", "BWELEO,MWINJUMA", "BWELEO,HALIMA", "MSUKA,SAID SALUM", "KANDWI,IBRAHIM", "KIUNGONI,HAITHAM", "SHARIF MSA,ZAINAB ADAMU AMIRI", "TONDOONI,MAKAME FAKI", "KIBONDENI,HAIRATI", "D. MCHANGANI,RIZIKI", "D. MCHANGANI,YUSRA", "UPENJA,JUMA", "SHAKANI,TUKENA", "NDAGONI,ASYA", "SHAKANI,KIHENGA", "MTAMBWE KASKAZINI,HAWA MALIK", "DUNGA K,SULEIMAN", "MIHOGONI,YUSSUF", "MAKANGALE,AISHA", "KIDANZINI,JOGHA", "KIDANZINI,SABRINA", "TUNGUU,ERNEST", "KIBONDENI,ASHRAK", "KINUNI,YUSSUF", "KISAUNI,MOHD OMAR KHAIID", "KITUMBA,HIDAYA SULEIMAN SAIDI", "PIKI,ISMAIL MSHAMATA", "KANDWI,KAZIJA", "K UPELE,HAJI", "K/UPELE,HAJI", "JENDELE,HAJI", "MWAKAJE,EMANUEL LUCAS", "CHUKWANI,MAIMUNA HASSAN", "MTANGANI,IDRISA", "MCHANGANI,RAMADHAN", "CHUWINI,AISAR", "CHIMBA,KHATIB ALI KHATIB", "JENDELE,TATU", "MAJENZI,KHALFANI ALI MASOUD", "JADIDA,TIME", "KIUYU MBUYUNI,BIKOMBO SALIM RASHID", "VITONGOJI,MAUA", "GOMBANI,HAFIDH", "MIZINGANI,KOMBO", "MWERA,RASHID", "M WERA,IDRISA", "KONDE,MARYAM", "CHUKWANI,ALI MZEE SALEH", "WAMBAA,MKASI KHATIB", "WAMBAA,SAID BARAKA", "WAMBAA,KADIRU SLEIMAN", "WAMBAA,IDRISA OTHMAN", "TUMBE MASHARIKI,HELENA MAULID MTAWA", "WAMBAA,MUHD OMI", "WAMBAA,IDRISA OTHMAN", "MFENESINI,AZIZ SULEIMAN", "WAMBAA,FATMA HIMID OMAR", "WAMBAA,FATMA HIMID OMAR", "WAMBAA,FATMA HIMID OMAR"];
        _.each(result.rows, function(row) {
          return _.each(dupeTargets, function(value) {
            var name, shehia, _ref;
            _ref = value.split(","), shehia = _ref[0], name = _ref[1];
            if (row.doc.shehia === shehia && row.doc.name === name) {
              if (found[value]) {
                return dupes.push(row.doc);
              } else {
                console.log("saving copy of " + (JSON.stringify(row.doc)));
                return found[value] = true;
              }
            }
          });
        });
        console.log(dupes);
        i = 0;
        return _.each(dupes, function(dupe) {
          i++;
          return $.couch.db(Coconut.config.database_name()).removeDoc(dupe);
        });
      }
    });
  };

  CleanView.prototype.searchForManualCaseIDs = function() {
    return this.resultCollection.each((function(_this) {
      return function(result) {
        return _.each(_.keys(result.attributes), function(key) {
          var caseID, recommendedChange;
          if (key.match(/MalariaCaseID/i)) {
            caseID = result.get(key);
            if (caseID != null) {
              if (!caseID.match(/[A-Z][A-Z][A-Z]\d\d\d/)) {
                recommendedChange = caseID.replace(/[\ \.\-\/_]/, "");
                recommendedChange = recommendedChange.toUpperCase();
                if (recommendedChange.match(/[A-Z][A-Z][A-Z]\d\d\d/)) {
                  if (_this.args === "apply_caseIDs") {
                    if (User.currentUser.username() !== "admin") {
                      throw "Must be admin";
                    }
                    result.save(key, recommendedChange);
                  }
                } else {
                  recommendedChange = "Fix manually";
                }
                return $("#caseIDs tbody").append("<tr> <td>" + caseID + "</td> <td>" + recommendedChange + "</td> </tr>");
              }
            }
          }
        });
      };
    })(this));
  };

  CleanView.prototype.searchForDates = function() {
    return this.resultCollection.each((function(_this) {
      return function(result) {
        return _.each(_.keys(result.attributes), function(key) {
          var cleanedDate, date;
          if (key.match(/date/i)) {
            date = result.get(key);
            if (date != null) {
              _this.total++;
              cleanedDate = _this.cleanDate(date);
              if (cleanedDate[1] !== "No action recommended") {
                $("#dates table").append("<tr> <td><a href='#show/case/" + (result.get("MalariaCaseID")) + "'>" + (result.get("MalariaCaseID")) + "</a></td> <td>" + key + "</td> <td>" + date + "</td> <td>" + cleanedDate[0] + "</td> <td>" + cleanedDate[1] + "</td> </tr>");
                if (_this.args === "apply_dates" && cleanedDate[0]) {
                  if (User.currentUser.username() !== "admin") {
                    throw "Must be admin";
                  }
                  return result.save(key, cleanedDate[0]);
                }
              }
            }
          }
        });
      };
    })(this));
  };

  CleanView.prototype.cleanDate = function(date) {
    var dateMatch, day, first, month, second, third, year;
    dateMatch = date.match(/^(\d+)([ -/])(\d+)([ -/])(\d+)$/);
    if (dateMatch) {
      first = dateMatch[1];
      second = dateMatch[3];
      third = dateMatch[5];
      if (second.match(/201\d/)) {
        return [null, "Invalid year"];
      }
      if (first.match(/201\d/)) {
        year = first;
        if (dateMatch[2] !== "-") {
          day = second;
          month = third;
          return [this.format(year, month, day), "Non dash separators, not generated by tablet, can assume yy,dd,mm"];
        } else {
          return [null, "No action recommended"];
        }
      } else if (third.match(/201\d/)) {
        day = first;
        month = second;
        year = third;
        return [this.format(year, month, day), "Year last, not generated by tablet, can assume dd,mm,yy"];
      } else {
        return [null, "Can't find a date"];
      }
    } else {
      return [null, "Can't find a date"];
    }
  };

  CleanView.prototype.format = function(year, month, day) {
    year = parseInt(year, 10);
    month = parseInt(month, 10);
    day = parseInt(day, 10);
    if (month < 10) {
      month = "0" + month;
    }
    if (day < 10) {
      day = "0" + day;
    }
    return "" + year + "-" + month + "-" + day;
  };

  return CleanView;

})(Backbone.View);
