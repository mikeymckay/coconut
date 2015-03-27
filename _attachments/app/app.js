var Coconut, Router,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

Router = (function(_super) {
  __extends(Router, _super);

  function Router() {
    this.userWithRoleLoggedIn = __bind(this.userWithRoleLoggedIn, this);
    return Router.__super__.constructor.apply(this, arguments);
  }

  Router.prototype.routes = {
    "login": "login",
    "logout": "logout",
    "design": "design",
    "select": "select",
    "search/results": "searchResults",
    "show/results/:question_id": "showResults",
    "new/result/:question_id": "newResult",
    "show/result/:result_id": "showResult",
    "edit/result/:result_id": "editResult",
    "delete/result/:result_id": "deleteResult",
    "delete/result/:result_id/:confirmed": "deleteResult",
    "edit/resultSummary/:question_id": "editResultSummary",
    "analyze/:form_id": "analyze",
    "delete/:question_id": "deleteQuestion",
    "edit/hierarchy/geo": "editGeoHierarchy",
    "edit/hierarchy/facility": "editFacilityHierarchy",
    "edit/:question_id": "editQuestion",
    "manage": "manage",
    "sync": "sync",
    "sync/send": "syncSend",
    "sync/get": "syncGet",
    "configure": "configure",
    "map": "map",
    "reports": "reports",
    "reports/*options": "reports",
    "summary": "summary",
    "transfer/:caseID": "transfer",
    "alerts": "alerts",
    "show/case/:caseID": "showCase",
    "show/case/:caseID/:docID": "showCase",
    "users": "users",
    "messaging": "messaging",
    "help": "help",
    "help/:helpDocument": "help",
    "clean": "clean",
    "clean/:startDate/:endDate": "clean",
    "csv/:question/startDate/:startDate/endDate/:endDate": "csv",
    "raw/userAnalysis/:startDate/:endDate": "rawUserAnalysis",
    "edit/data/:document_type": "editData",
    "": "default"
  };

  Router.prototype.route = function(route, name, callback) {
    Backbone.history || (Backbone.history = new Backbone.History);
    if (!_.isRegExp(route)) {
      route = this._routeToRegExp(route);
    }
    return Backbone.history.route(route, (function(_this) {
      return function(fragment) {
        var args;
        args = _this._extractParameters(route, fragment);
        callback.apply(_this, args);
        $('#loading').slideDown();
        _this.trigger.apply(_this, ['route:' + name].concat(args));
        return $('#loading').fadeOut();
      };
    })(this), this);
  };

  Router.prototype.userLoggedIn = function(callback) {
    return User.isAuthenticated({
      success: function(user) {
        return callback.success(user);
      },
      error: function() {
        Coconut.loginView.callback = callback;
        return Coconut.loginView.render();
      }
    });
  };

  Router.prototype.rawUserAnalysis = function(startDate, endDate) {
    $("body").html("");
    return Reports.userAnalysis({
      usernames: Users.map(function(user) {
        return user.username();
      }),
      startDate: startDate,
      endDate: endDate,
      success: function(result) {
        return $("body").html("<span id='json'>" + (JSON.stringify(result)) + "</span>");
      }
    });
  };

  Router.prototype.csv = function(question, startDate, endDate) {
    return this.userLoggedIn({
      success: function() {
        var csvView;
        if (User.currentUser.hasRole("reports")) {
          csvView = new CsvView;
          csvView.question = question;
          csvView.startDate = endDate;
          csvView.endDate = startDate;
          return csvView.render();
        }
      }
    });
  };

  Router.prototype.editGeoHierarchy = function() {
    return this.adminLoggedIn({
      success: function() {
        if (!Coconut.GeoHierarchyView) {
          Coconut.GeoHierarchyView = new GeoHierarchyView();
        }
        return Coconut.GeoHierarchyView.render();
      },
      error: function() {
        return alert(User.currentUser + " is not an admin");
      }
    });
  };

  Router.prototype.editFacilityHierarchy = function() {
    return this.adminLoggedIn({
      success: function() {
        if (!Coconut.FacilityHierarchyView) {
          Coconut.FacilityHierarchyView = new FacilityHierarchyView();
        }
        return Coconut.FacilityHierarchyView.render();
      },
      error: function() {
        return alert(User.currentUser + " is not an admin");
      }
    });
  };

  Router.prototype.editData = function(document_id) {
    return this.adminLoggedIn({
      success: function() {
        if (!Coconut.EditDataView) {
          Coconut.EditDataView = new EditDataView();
        }
        return $.couch.db(Coconut.config.database_name()).openDoc(document_id, {
          error: function() {
            Coconut.EditDataView.document = {
              _id: document_id
            };
            return Coconut.EditDataView.render();
          },
          success: function(result) {
            Coconut.EditDataView.document = result;
            return Coconut.EditDataView.render();
          }
        });
      },
      error: function() {
        return alert(User.currentUser + " is not an admin");
      }
    });
  };

  Router.prototype.clean = function(startDate, endDate, option) {
    var redirect;
    redirect = false;
    if (!startDate) {
      startDate = moment().subtract(3, "month").format("YYYY-MM-DD");
      redirect = true;
    }
    if (!endDate) {
      endDate = moment().subtract(1, "month").format("YYYY-MM-DD");
      redirect = true;
    }
    if (redirect) {
      Coconut.router.navigate("clean/" + startDate + "/" + endDate, true);
    }
    return this.userLoggedIn({
      success: function() {
        if (Coconut.cleanView == null) {
          Coconut.cleanView = new CleanView();
        }
        Coconut.cleanView.startDate = startDate;
        Coconut.cleanView.endDate = endDate;
        return Coconut.cleanView.render();
      }
    });
  };

  Router.prototype.help = function(helpDocument) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.helpView == null) {
          Coconut.helpView = new HelpView();
        }
        if (helpDocument != null) {
          Coconut.helpView.helpDocument = helpDocument;
        } else {
          Coconut.helpView.helpDocument = null;
        }
        return Coconut.helpView.render();
      }
    });
  };

  Router.prototype.users = function() {
    return this.adminLoggedIn({
      success: function() {
        if (Coconut.usersView == null) {
          Coconut.usersView = new UsersView();
        }
        return Coconut.usersView.render();
      }
    });
  };

  Router.prototype.messaging = function() {
    return this.adminLoggedIn({
      success: function() {
        if (Coconut.messagingView == null) {
          Coconut.messagingView = new MessagingView();
        }
        return Coconut.messagingView.render();
      }
    });
  };

  Router.prototype.login = function() {
    Coconut.loginView.callback = {
      success: function() {
        return Coconut.router.navigate("", true);
      }
    };
    return Coconut.loginView.render();
  };

  Router.prototype.userWithRoleLoggedIn = function(role, callback) {
    return this.userLoggedIn({
      success: function(user) {
        if (user.hasRole(role)) {
          return callback.success(user);
        } else {
          return $("#content").html("<h2>User '" + (user.username()) + "' must have role: '" + role + "'</h2>");
        }
      },
      error: function() {
        return $("#content").html("<h2>User '" + (user.username()) + "' must have role: '" + role + "'</h2>");
      }
    });
  };

  Router.prototype.adminLoggedIn = function(callback) {
    return this.userLoggedIn({
      success: function(user) {
        console.log(user);
        if (user.isAdmin()) {
          return callback.success(user);
        }
      },
      error: function() {
        return $("#content").html("<h2>Must be an admin user</h2>");
      }
    });
  };

  Router.prototype.logout = function() {
    User.logout();
    Coconut.router.navigate("", true);
    return document.location.reload();
  };

  Router.prototype["default"] = function() {
    return this.userLoggedIn({
      success: function() {
        if (User.currentUser.hasRole("reports")) {
          Coconut.router.navigate("reports", true);
        }
        return $("#content").html("");
      }
    });
  };

  Router.prototype.reports = function(options) {
    var showReports;
    showReports = (function(_this) {
      return function() {
        var reportViewOptions;
        options = _(options != null ? options.split(/\//) : void 0).map(function(option) {
          return unescape(option);
        });
        reportViewOptions = {};
        _.each(options, function(option, index) {
          if (!(index % 2)) {
            return reportViewOptions[option] = options[index + 1];
          }
        });
        if (Coconut.reportView == null) {
          Coconut.reportView = new ReportView();
        }
        return Coconut.reportView.render(reportViewOptions);
      };
    })(this);
    if (document.location.hash === "#reports/reportType/periodSummary/alertEmail/true") {
      return showReports();
    } else {
      return this.userWithRoleLoggedIn("reports", {
        success: function() {
          return showReports();
        }
      });
    }
  };

  Router.prototype.summary = function() {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.summaryView == null) {
          Coconut.summaryView = new SummaryView();
        }
        return $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/casesWithSummaryData", {
          descending: true,
          include_docs: false,
          limit: 100,
          success: (function(_this) {
            return function(result) {
              return Coconut.summaryView.render(result);
            };
          })(this)
        });
      }
    });
  };

  Router.prototype.transfer = function(caseID) {
    return this.userLoggedIn({
      success: function() {
        var caseResults;
        $("#content").html("<h2> Select a user to transfer " + caseID + " to: </h2> <select id='users'> <option></option> </select> <br/> <button onClick='window.history.back()'>Cancel</button> <h3>Case Results to be transferred</h3> <div id='caseinfo'></div>");
        caseResults = [];
        $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/cases", {
          key: caseID,
          include_docs: true,
          error: (function(_this) {
            return function(error) {
              return console.error(error);
            };
          })(this),
          success: (function(_this) {
            return function(result) {
              caseResults = _.pluck(result.rows, "doc");
              $.couch.db(Coconut.config.database_name()).view((Coconut.config.design_doc_name()) + "/users", {
                success: function(result) {
                  return $("#content select").append(_.map(result.rows, function(user) {
                    if (user.key == null) {
                      return "";
                    }
                    return "<option id='" + user.id + "'>" + user.key + "   " + (user.value.join("   ")) + "</option>";
                  }).join(""));
                }
              });
              $("#caseinfo").html(_(caseResults).map(function(caseResult) {
                return "<pre> " + (JSON.stringify(caseResult, null, 2)) + " </pre>";
              }).join("<br/>"));
              $("select").selectmenu();
              return $("button").button();
            };
          })(this)
        });
        return $("select").change(function() {
          var user;
          user = $('select').find(":selected").text();
          if (confirm("Are you sure you want to transfer Case:" + caseID + " to " + user + "?")) {
            _(caseResults).each(function(caseResult) {
              Coconut.debug("Marking " + caseResult._id + " as transferred");
              if (caseResult.transferred == null) {
                caseResult.transferred = [];
              }
              return caseResult.transferred.push({
                from: User.currentUser.get("_id"),
                to: $('select').find(":selected").attr("id"),
                time: moment().format("YYYY-MM-DD HH:mm"),
                notifiedViaSms: [],
                received: false
              });
            });
            return $.couch.db(Coconut.config.database_name()).bulkSave({
              docs: caseResults
            }, {
              error: (function(_this) {
                return function(error) {
                  return Coconut.debug("Could not save " + (JSON.stringify(caseResults)) + ": " + (JSON.stringify(error)));
                };
              })(this),
              success: (function(_this) {
                return function() {
                  return Coconut.router.navigate("sync/send", true);
                };
              })(this)
            });
          }
        });
      }
    });
  };

  Router.prototype.showCase = function(caseID, docID) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.caseView == null) {
          Coconut.caseView = new CaseView();
        }
        Coconut.caseView["case"] = new Case({
          caseID: caseID
        });
        return Coconut.caseView["case"].fetch({
          success: function() {
            return Coconut.caseView.render(docID);
          }
        });
      }
    });
  };

  Router.prototype.configure = function() {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.localConfigView == null) {
          Coconut.localConfigView = new LocalConfigView();
        }
        return Coconut.localConfigView.render();
      }
    });
  };

  Router.prototype.editResultSummary = function(question_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.resultSummaryEditor == null) {
          Coconut.resultSummaryEditor = new ResultSummaryEditorView();
        }
        Coconut.resultSummaryEditor.question = new Question({
          id: unescape(question_id)
        });
        return Coconut.resultSummaryEditor.question.fetch({
          success: function() {
            return Coconut.resultSummaryEditor.render();
          }
        });
      }
    });
  };

  Router.prototype.editQuestion = function(question_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.designView == null) {
          Coconut.designView = new DesignView();
        }
        Coconut.designView.render();
        return Coconut.designView.loadQuestion(unescape(question_id));
      }
    });
  };

  Router.prototype.deleteQuestion = function(question_id) {
    return this.userLoggedIn({
      success: function() {
        return Coconut.questions.get(unescape(question_id)).destroy({
          success: function() {
            Coconut.menuView.render();
            return Coconut.router.navigate("manage", true);
          }
        });
      }
    });
  };

  Router.prototype.sync = function(action) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.syncView == null) {
          Coconut.syncView = new SyncView();
        }
        return Coconut.syncView.render();
      }
    });
  };

  Router.prototype.syncSend = function(action) {
    Coconut.router.navigate("", false);
    return this.userLoggedIn({
      success: function() {
        if (Coconut.syncView == null) {
          Coconut.syncView = new SyncView();
        }
        Coconut.syncView.render();
        return Coconut.syncView.sync.sendToCloud({
          success: function() {
            return Coconut.syncView.update();
          },
          error: function() {
            return Coconut.syncView.update();
          }
        });
      }
    });
  };

  Router.prototype.syncGet = function(action) {
    Coconut.router.navigate("", false);
    return this.userLoggedIn({
      success: function() {
        if (Coconut.syncView == null) {
          Coconut.syncView = new SyncView();
        }
        Coconut.syncView.render();
        return Coconut.syncView.sync.getFromCloud();
      }
    });
  };

  Router.prototype.manage = function() {
    return this.adminLoggedIn({
      success: function() {
        if (Coconut.manageView == null) {
          Coconut.manageView = new ManageView();
        }
        return Coconut.manageView.render();
      }
    });
  };

  Router.prototype.newResult = function(question_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.questionView == null) {
          Coconut.questionView = new QuestionView();
        }
        Coconut.questionView.result = new Result({
          question: unescape(question_id)
        });
        Coconut.questionView.model = new Question({
          id: unescape(question_id)
        });
        return Coconut.questionView.model.fetch({
          success: function() {
            return Coconut.questionView.render();
          }
        });
      }
    });
  };

  Router.prototype.searchResults = function() {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.searchResultsView == null) {
          Coconut.searchResultsView = new SearchResultsView();
        }
        return Coconut.searchResultsView.render();
      }
    });
  };

  Router.prototype.showResult = function(result_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.questionView == null) {
          Coconut.questionView = new QuestionView();
        }
        Coconut.questionView.readonly = true;
        Coconut.questionView.result = new Result({
          _id: result_id
        });
        return Coconut.questionView.result.fetch({
          success: function() {
            var question;
            question = Coconut.questionView.result.question();
            if (question != null) {
              Coconut.questionView.model = new Question({
                id: question
              });
              return Coconut.questionView.model.fetch({
                success: function() {
                  return Coconut.questionView.render();
                }
              });
            } else {
              $("#content").html("<button id='delete' type='button'>Delete</button> <pre>" + (JSON.stringify(Coconut.questionView.result, null, 2)) + "</pre>");
              return $("button#delete").click(function() {
                if (confirm("Are you sure you want to delete this result?")) {
                  return Coconut.questionView.result.destroy({
                    success: function() {
                      $("#content").html("Result deleted, redirecting...");
                      return _.delay(function() {
                        return Coconut.router.navigate("/", true);
                      }, 2000);
                    }
                  });
                }
              });
            }
          }
        });
      }
    });
  };

  Router.prototype.editResult = function(result_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.questionView == null) {
          Coconut.questionView = new QuestionView();
        }
        Coconut.questionView.readonly = false;
        Coconut.questionView.result = new Result({
          _id: result_id
        });
        return Coconut.questionView.result.fetch({
          success: function() {
            var question;
            question = Coconut.questionView.result.question();
            if (question != null) {
              Coconut.questionView.model = new Question({
                id: question
              });
              return Coconut.questionView.model.fetch({
                success: function() {
                  return Coconut.questionView.render();
                }
              });
            } else {
              $("#content").html("<button id='delete' type='button'>Delete</button> <br/> (Editing not supported for USSD Notifications) <br/> <pre>" + (JSON.stringify(Coconut.questionView.result, null, 2)) + "</pre>");
              return $("button#delete").click(function() {
                if (confirm("Are you sure you want to delete this result?")) {
                  return Coconut.questionView.result.destroy({
                    success: function() {
                      $("#content").html("Result deleted, redirecting...");
                      return _.delay(function() {
                        return Coconut.router.navigate("/", true);
                      }, 2000);
                    }
                  });
                }
              });
            }
          }
        });
      }
    });
  };

  Router.prototype.deleteResult = function(result_id, confirmed) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.questionView == null) {
          Coconut.questionView = new QuestionView();
        }
        Coconut.questionView.readonly = true;
        Coconut.questionView.result = new Result({
          _id: result_id
        });
        return Coconut.questionView.result.fetch({
          success: function() {
            var question;
            question = Coconut.questionView.result.question();
            if (question != null) {
              if (confirmed === "confirmed") {
                return Coconut.questionView.result.destroy({
                  success: function() {
                    Coconut.menuView.update();
                    return Coconut.router.navigate("show/results/" + (escape(Coconut.questionView.result.question())), true);
                  }
                });
              } else {
                Coconut.questionView.model = new Question({
                  id: question
                });
                return Coconut.questionView.model.fetch({
                  success: function() {
                    Coconut.questionView.render();
                    $("#content").prepend("<h2>Are you sure you want to delete this result?</h2> <div id='confirm'> <a href='#delete/result/" + result_id + "/confirmed'>Yes</a> <a href='#show/results/" + (escape(Coconut.questionView.result.question())) + "'>Cancel</a> </div>");
                    $("#confirm a").button();
                    $("#content form").css({
                      "background-color": "#333",
                      "margin": "50px",
                      "padding": "10px"
                    });
                    return $("#content form label").css({
                      "color": "white"
                    });
                  }
                });
              }
            } else {
              return Coconut.router.navigate("edit/result/" + result_id, true);
            }
          }
        });
      }
    });
  };

  Router.prototype.design = function() {
    return this.userLoggedIn({
      success: function() {
        $("#content").empty();
        if (Coconut.designView == null) {
          Coconut.designView = new DesignView();
        }
        return Coconut.designView.render();
      }
    });
  };

  Router.prototype.showResults = function(question_id) {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.resultsView == null) {
          Coconut.resultsView = new ResultsView();
        }
        Coconut.resultsView.question = new Question({
          id: unescape(question_id)
        });
        return Coconut.resultsView.question.fetch({
          success: function() {
            return Coconut.resultsView.render();
          }
        });
      }
    });
  };

  Router.prototype.map = function() {
    return this.userLoggedIn({
      success: function() {
        if (Coconut.mapView == null) {
          Coconut.mapView = new MapView();
        }
        return Coconut.mapView.render();
      }
    });
  };

  Router.prototype.startApp = function() {
    Coconut.config = new Config();
    return Coconut.config.fetch({
      success: function() {
        var classesToLoad, onOffline, onOnline, startApplication;
        if (Coconut.config.local.get("mode") === "cloud") {
          $("body").append("<script src='http://maps.google.com/maps/api/js?v=3&sensor=false'></script>");
          $("body").append("<style> .leaflet-map-pane { z-index: 2 !important; } .leaflet-google-layer { z-index: 1 !important; } </style>");
        }
        $("#footer-menu").html("<center> <span style='font-size:75%;display:inline-block'> <span id='district'></span><br/> <span id='user'></span> </span> <a href='#login'>Login</a> <a href='#logout'>Logout</a> " + (Coconut.config.local.get("mode") === "cloud" ? "<a id='reports-button' href='#reports'>Reports</a>" : (onOffline = function(event) {
          return alert("offline");
        }, onOnline = function(event) {
          return alert("online");
        }, document.addEventListener("offline", onOffline, false), document.addEventListener("online", onOnline, false), "<a href='#sync/send'>Send data (last success: <span class='sync-sent-status'></span>)</a> <a href='#sync/get'>Get data (last success: <span class='sync-get-status'></span>)</a>")) + " &nbsp; <a id='manage-button' style='display:none' href='#manage'>Manage</a> &nbsp; <a href='#help'>Help</a> <span style='font-size:75%;display:inline-block'>Version<br/><span id='version'></span></span> <span style='font-size:75%;display:inline-block'><br/><span id='databaseStatus'></span></span> </center>");
        $("[data-role=footer]").navbar();
        $('#application-title').html(Coconut.config.title());
        _(["shehias_high_risk", "shehias_received_irs"]).each(function(docId) {
          return $.couch.db("zanzibar").openDoc(docId, {
            error: function(error) {
              return console.error(JSON.stringify(error));
            },
            success: function(result) {
              return Coconut[docId] = result;
            }
          });
        });
        classesToLoad = [FacilityHierarchy, GeoHierarchy];
        startApplication = _.after(classesToLoad.length, function() {
          Coconut.loginView = new LoginView();
          Coconut.questions = new QuestionCollection();
          Coconut.questionView = new QuestionView();
          Coconut.menuView = new MenuView();
          Coconut.syncView = new SyncView();
          Coconut.menuView.render();
          Coconut.syncView.update();
          return Backbone.history.start();
        });
        return _.each(classesToLoad, function(ClassToLoad) {
          return ClassToLoad.load({
            success: function() {
              return startApplication();
            },
            error: function(error) {
              alert("Could not load " + ClassToLoad + ": " + error + ". Recommendation: Press get data again.");
              return startApplication();
            }
          });
        });
      },
      error: function() {
        if (Coconut.localConfigView == null) {
          Coconut.localConfigView = new LocalConfigView();
        }
        return Coconut.localConfigView.render();
      }
    });
  };

  return Router;

})(Backbone.Router);

Coconut = {};

Coconut.router = new Router();

Coconut.router.startApp();

Coconut.debug = function(string) {
  console.log(string);
  return $("#log").append(string + "<br/>");
};

Coconut.identifyingAttributes = ["Name", "name", "FirstName", "MiddleName", "LastName", "ContactMobilepatientrelative", "HeadofHouseholdName", "ShehaMjumbe"];

Coconut.IRSThresholdInMonths = 6;
