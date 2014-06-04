var Sync,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Sync = (function(_super) {
  __extends(Sync, _super);

  function Sync() {
    this.replicateApplicationDocs = __bind(this.replicateApplicationDocs, this);
    this.transferCasesIn = __bind(this.transferCasesIn, this);
    this.convertNotificationToCaseNotification = __bind(this.convertNotificationToCaseNotification, this);
    this.getFromCloud = __bind(this.getFromCloud, this);
    this.log = __bind(this.log, this);
    this.last_get_time = __bind(this.last_get_time, this);
    this.was_last_get_successful = __bind(this.was_last_get_successful, this);
    this.last_send_time = __bind(this.last_send_time, this);
    this.was_last_send_successful = __bind(this.was_last_send_successful, this);
    this.last_send = __bind(this.last_send, this);
    return Sync.__super__.constructor.apply(this, arguments);
  }

  Sync.prototype.initialize = function() {
    return this.set({
      _id: "SyncLog"
    });
  };

  Sync.prototype.url = "/sync";

  Sync.prototype.target = function() {
    return Coconut.config.cloud_url();
  };

  Sync.prototype.last_send = function() {
    return this.get("last_send_result");
  };

  Sync.prototype.was_last_send_successful = function() {
    var last_send_data;
    if (this.get("last_send_error") === true) {
      return false;
    }
    last_send_data = this.last_send();
    if (last_send_data == null) {
      return false;
    }
    if ((last_send_data.no_changes != null) && last_send_data.no_changes === true) {
      return true;
    }
    return (last_send_data.docs_read === last_send_data.docs_written) && last_send_data.doc_write_failures === 0;
  };

  Sync.prototype.last_send_time = function() {
    var result;
    result = this.get("last_send_time");
    if (result) {
      return moment(this.get("last_send_time")).fromNow();
    } else {
      return "never";
    }
  };

  Sync.prototype.was_last_get_successful = function() {
    return this.get("last_get_success");
  };

  Sync.prototype.last_get_time = function() {
    var result;
    result = this.get("last_get_time");
    if (result) {
      return moment(this.get("last_get_time")).fromNow();
    } else {
      return "never";
    }
  };

  Sync.prototype.sendToCloud = function(options) {
    return this.fetch({
      error: (function(_this) {
        return function(error) {
          return _this.log("Unable to fetch Sync doc: " + (JSON.stringify(error)));
        };
      })(this),
      success: (function(_this) {
        return function() {
          _this.log("Checking for internet. (Is " + (Coconut.config.cloud_url()) + " is reachable?) Please wait.");
          return $.ajax({
            dataType: "jsonp",
            url: Coconut.config.cloud_url(),
            error: function(error) {
              _this.log("ERROR! " + (Coconut.config.cloud_url()) + " is not reachable. Do you have enough airtime? Are you on WIFI?  Either the internet is not working or the site is down: " + (JSON.stringify(error)));
              options.error();
              return _this.save({
                last_send_error: true
              });
            },
            success: function() {
              _this.log("" + (Coconut.config.cloud_url()) + " is reachable, so internet is available.");
              _this.log("Creating list of all results on the tablet. Please wait.");
              return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/results", {
                include_docs: false,
                error: function(result) {
                  _this.log("Could not retrieve list of results: " + (JSON.stringify(error)));
                  options.error();
                  return _this.save({
                    last_send_error: true
                  });
                },
                success: function(result) {
                  var resultIDs;
                  _this.log("Synchronizing " + result.rows.length + " results. Please wait.");
                  resultIDs = _.pluck(result.rows, "id");
                  return $.couch.db(Coconut.config.database_name()).saveDoc({
                    collection: "log",
                    action: "sendToCloud",
                    user: User.currentUser.id,
                    time: moment().format(Coconut.config.get("date_format"))
                  }, {
                    error: function(error) {
                      return _this.log("Could not create log file: " + (JSON.stringify(error)));
                    },
                    success: function() {
                      $.couch.replicate(Coconut.config.database_name(), Coconut.config.cloud_url_with_credentials(), {
                        success: function(result) {
                          _this.log("Send data finished: created, updated or deleted " + result.docs_written + " results on the server.");
                          _this.save({
                            last_send_result: result,
                            last_send_error: false,
                            last_send_time: new Date().getTime()
                          });
                          return _this.sendLogMessagesToCloud({
                            success: function() {
                              return options.success();
                            },
                            error: function(error) {
                              this.save({
                                last_send_error: true
                              });
                              return options.error(error);
                            }
                          });
                        }
                      }, {
                        doc_ids: resultIDs
                      });
                      return Coconut.menuView.checkReplicationStatus();
                    }
                  });
                }
              });
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.log = function(message) {
    return Coconut.debug(message);
  };

  Sync.prototype.sendLogMessagesToCloud = function(options) {
    return this.fetch({
      error: (function(_this) {
        return function(error) {
          return _this.log("Unable to fetch Sync doc: " + (JSON.stringify(error)));
        };
      })(this),
      success: (function(_this) {
        return function() {
          return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/byCollection", {
            key: "log",
            include_docs: false,
            error: function(error) {
              _this.log("Could not retrieve list of log entries: " + (JSON.stringify(error)));
              options.error(error);
              return _this.save({
                last_send_error: true
              });
            },
            success: function(result) {
              var logIDs;
              _this.log("Sending " + result.rows.length + " log entries. Please wait.");
              logIDs = _.pluck(result.rows, "id");
              $.couch.replicate(Coconut.config.database_name(), Coconut.config.cloud_url_with_credentials(), {
                success: function(result) {
                  _this.save({
                    last_send_result: result,
                    last_send_error: false,
                    last_send_time: new Date().getTime()
                  });
                  _this.log("Successfully sent " + result.docs_written + " log messages to the server.");
                  return options.success();
                },
                error: function(error) {
                  _this.log("Could not send log messages to the server: " + (JSON.stringify(error)));
                  _this.save({
                    last_send_error: true
                  });
                  return typeof options.error === "function" ? options.error(error) : void 0;
                }
              }, {
                doc_ids: logIDs
              });
              return Coconut.menuView.checkReplicationStatus();
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.getFromCloud = function(options) {
    return this.fetch({
      error: (function(_this) {
        return function(error) {
          return _this.log("Unable to fetch Sync doc: " + (JSON.stringify(error)));
        };
      })(this),
      success: (function(_this) {
        return function() {
          _this.log("Checking that " + (Coconut.config.cloud_url()) + " is reachable. Please wait.");
          return $.ajax({
            dataType: "jsonp",
            url: Coconut.config.cloud_url(),
            error: function(error) {
              _this.log("ERROR! " + (Coconut.config.cloud_url()) + " is not reachable. Do you have enough airtime? Are you on WIFI?  Either the internet is not working or the site is down: " + (JSON.stringify(error)));
              return typeof options.error === "function" ? options.error(error) : void 0;
            },
            success: function() {
              _this.log("" + (Coconut.config.cloud_url()) + " is reachable, so internet is available.");
              return _this.fetch({
                success: function() {
                  return _this.getNewNotifications({
                    success: function() {
                      return $.couch.login({
                        name: Coconut.config.get("local_couchdb_admin_username"),
                        password: Coconut.config.get("local_couchdb_admin_password"),
                        error: function(error) {
                          _this.log("ERROR logging in as local admin: " + (JSON.stringify(error)));
                          return options != null ? typeof options.error === "function" ? options.error() : void 0 : void 0;
                        },
                        success: function() {
                          _this.log("Updating users, forms and the design document. Please wait.");
                          return _this.replicateApplicationDocs({
                            error: function(error) {
                              $.couch.logout();
                              _this.log("ERROR updating application: " + (JSON.stringify(error)));
                              _this.save({
                                last_get_success: false
                              });
                              return options != null ? typeof options.error === "function" ? options.error(error) : void 0 : void 0;
                            },
                            success: function() {
                              $.couch.logout();
                              return $.couch.db(Coconut.config.database_name()).saveDoc({
                                collection: "log",
                                action: "getFromCloud",
                                user: User.currentUser.id,
                                time: moment().format(Coconut.config.get("date_format"))
                              }, {
                                error: function(error) {
                                  return _this.log("Could not create log file " + (JSON.stringify(error)));
                                },
                                success: function() {
                                  return _this.transferCasesIn({
                                    success: function() {
                                      _this.log("Sending log messages to cloud.");
                                      return _this.sendLogMessagesToCloud({
                                        success: function() {
                                          _this.log("Finished, refreshing app in 5 seconds...");
                                          return _this.fetch({
                                            error: function(error) {
                                              return _this.log("Unable to fetch Sync doc: " + (JSON.stringify(error)));
                                            },
                                            success: function() {
                                              _this.save({
                                                last_get_success: true,
                                                last_get_time: new Date().getTime()
                                              });
                                              if (options != null) {
                                                if (typeof options.success === "function") {
                                                  options.success();
                                                }
                                              }
                                              return _.delay(function() {
                                                return document.location.reload();
                                              }, 5000);
                                            }
                                          });
                                        }
                                      });
                                    }
                                  });
                                }
                              });
                            }
                          });
                        }
                      });
                    }
                  });
                }
              });
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.getNewNotifications = function(options) {
    this.log("Looking for most recent Case Notification on tablet. Please wait.");
    return $.couch.db(Coconut.config.database_name()).view("" + (Coconut.config.design_doc_name()) + "/rawNotificationsConvertedToCaseNotifications", {
      descending: true,
      include_docs: true,
      limit: 1,
      error: (function(_this) {
        return function(error) {
          return _this.log("Unable to find the the most recent case notification: " + (JSON.stringify(error)));
        };
      })(this),
      success: (function(_this) {
        return function(result) {
          var dateToStartLooking, mostRecentNotification, url, _ref, _ref1;
          mostRecentNotification = (_ref = result.rows) != null ? (_ref1 = _ref[0]) != null ? _ref1.doc.date : void 0 : void 0;
          if ((mostRecentNotification != null) && moment(mostRecentNotification).isBefore((new moment).subtract('weeks', 3))) {
            dateToStartLooking = mostRecentNotification;
          } else {
            dateToStartLooking = (new moment).subtract('weeks', 3).format(Coconut.config.get("date_format"));
          }
          url = "" + (Coconut.config.cloud_url_with_credentials()) + "/_design/" + (Coconut.config.design_doc_name()) + "/_view/rawNotificationsNotConvertedToCaseNotifications?&ascending=true&include_docs=true";
          url += "&startkey=\"" + dateToStartLooking + "\"&skip=1";
          return $.ajax({
            url: "/zanzibar/district_language_mapping",
            dataType: "json",
            error: function(result) {
              return alert("Couldn't find english_to_swahili map: " + (JSON.stringify(result)));
            },
            success: function(result) {
              var district_language_mapping;
              district_language_mapping = result.english_to_swahili;
              _this.log("Looking for USSD notifications without Case Notifications after " + dateToStartLooking + ". Please wait.");
              return $.ajax({
                url: url,
                dataType: "jsonp",
                error: function(error) {
                  return _this.log("ERROR, could not download USSD notifications: " + (JSON.stringify(error)));
                },
                success: function(result) {
                  var currentUserDistrict;
                  currentUserDistrict = User.currentUser.get("district");
                  _this.log("Found " + result.rows.length + " USSD notifications. Filtering for USSD notifications for district:  " + currentUserDistrict + ". Please wait.");
                  _.each(result.rows, function(row) {
                    var districtForNotification, notification;
                    notification = row.doc;
                    districtForNotification = notification.facility_district;
                    if (district_language_mapping[districtForNotification] != null) {
                      districtForNotification = district_language_mapping[districtForNotification];
                    }
                    if (!_(GeoHierarchy.allDistricts()).contains(districtForNotification)) {
                      _this.log("" + districtForNotification + " not valid district, trying to use health facility: " + notification.hf + " to identify district");
                      if (FacilityHierarchy.getDistrict(notification.hf) != null) {
                        districtForNotification = FacilityHierarchy.getDistrict(notification.hf);
                        _this.log("Using district: " + districtForNotification + " indicated by health facility.");
                      } else {
                        _this.log("Can't find a valid district for health facility: " + notification.hf);
                      }
                      if (!_(GeoHierarchy.allDistricts()).contains(districtForNotification)) {
                        _this.log("" + districtForNotification + " still not valid district, trying to use shehia name to identify district: " + notification.shehia);
                        if (GeoHierarchy.findOneShehia(notification.shehia) != null) {
                          districtForNotification = GeoHierarchy.findOneShehia(notification.shehia).DISTRCT;
                          _this.log("Using district: " + districtForNotification + " indicated by shehia.");
                        } else {
                          _this.log("Can't find a valid district using shehia for notification: " + (JSON.stringify(notification)) + ".");
                        }
                      }
                    }
                    _this.log("Notifications for district: " + districtForNotification);
                    if (districtForNotification === currentUserDistrict) {
                      if (confirm("Accept new case? Facility: " + notification.hf + ", Shehia: " + notification.shehia + ", Name: " + notification.name + ", ID: " + notification.caseid + ", date: " + notification.date + ". You may need to coordinate with another DMSO.")) {
                        return convertNotificationToCaseNotification(notification);
                      } else {
                        return _this.log("Case notification " + notification.caseid + ", not accepted by " + (User.currentUser.username()));
                      }
                    }
                  });
                  return typeof options.success === "function" ? options.success() : void 0;
                }
              });
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.convertNotificationToCaseNotification = function(notification) {
    var Result;
    Result = new Result({
      question: "Case Notification",
      MalariaCaseID: notification.caseid,
      FacilityName: notification.hf,
      Shehia: notification.shehia,
      Name: notification.name
    });
    return result.save(null, {
      error: (function(_this) {
        return function(error) {
          return _this.log("Could not save " + (result.toJSON()) + ":  " + (JSON.stringify(error)));
        };
      })(this),
      success: (function(_this) {
        return function(error) {
          notification.hasCaseNotification = true;
          return $.couch.db(Coconut.config.database_name()).saveDoc(notification, {
            error: function(error) {
              return _this.log("Could not save notification " + (JSON.stringify(notification)) + " : " + (JSON.stringify(error)));
            },
            success: function() {
              var doc_ids;
              _this.log("Created new case notification " + (result.get("MalariaCaseID")) + " for patient " + (result.get("Name")) + " at " + (result.get("FacilityName")));
              doc_ids = [result.get("_id"), notification._id];
              return $.couch.replicate(Coconut.config.database_name(), Coconut.config.cloud_url_with_credentials(), {
                error: function(error) {
                  return _this.log("Error replicating " + doc_ids + " back to server: " + (JSON.stringify(error)));
                },
                success: function(result) {
                  _this.log("Sent docs: " + doc_ids);
                  return _this.save({
                    last_send_result: result,
                    last_send_error: false,
                    last_send_time: new Date().getTime()
                  });
                }
              }, {
                doc_ids: doc_ids
              });
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.transferCasesIn = function(options) {
    this.log("Checking cloud server for cases transferred to " + (User.currentUser.username()));
    return $.ajax({
      dataType: "jsonp",
      url: "" + (Coconut.config.cloud_url_with_credentials()) + "/_design/" + (Coconut.config.design_doc_name()) + "/_view/resultsAndNotificationsNotReceivedByTargetUser",
      data: {
        include_docs: true,
        key: JSON.stringify(User.currentUser.get("_id"))
      },
      error: (function(_this) {
        return function(a, b, error) {
          _this.log("Could not retrieve list of results: " + (JSON.stringify(error)));
          if (options != null) {
            options.error(error);
          }
          return _this.save({
            last_send_error: true
          });
        };
      })(this),
      success: (function(_this) {
        return function(result) {
          var caseSuccessHandler, cases;
          cases = {};
          _(result.rows).each(function(row) {
            var caseId;
            caseId = row.value[1];
            if (!cases[caseId]) {
              cases[caseId] = [];
            }
            return cases[caseId].push(row.doc);
          });
          if (_(cases).isEmpty()) {
            _this.log("No cases to transfer.");
          }
          caseSuccessHandler = _.after(cases.length, options != null ? options.success() : void 0);
          return _(cases).each(function(resultDocs) {
            var caseId, malariaCase, resultsSuccessHandler;
            malariaCase = new Case();
            malariaCase.loadFromResultDocs(resultDocs);
            caseId = malariaCase.MalariaCaseID();
            if (!confirm("Accept transfer case " + caseId + " " + (malariaCase.indexCasePatientName()) + " from facility " + (malariaCase.facility()) + " in " + (malariaCase.district()) + "?")) {
              return caseSuccessHandler();
            } else {
              resultsSuccessHandler = _.after(resultDocs.length, caseSuccessHandler());
              return _(resultDocs).each(function(resultDoc) {
                resultDoc.transferred[resultDoc.transferred.length - 1].received = true;
                return $.couch.db(Coconut.config.database_name()).saveDoc(resultDoc, {
                  error: function(error) {
                    return _this.log("ERROR: " + caseId + ": " + (resultDoc.question || "Notification") + " could not be saved on tablet: " + (JSON.stringify(error)));
                  },
                  success: function(success) {
                    _this.log("" + caseId + ": " + (resultDoc.question || "Notification") + " saved on tablet");
                    return $.couch.replicate(Coconut.config.database_name(), Coconut.config.cloud_url_with_credentials(), {
                      success: function() {
                        _this.log("" + caseId + ": " + (resultDoc.question || "Notification") + " marked as received in cloud");
                        return resultsSuccessHandler();
                      },
                      error: function(error) {
                        return _this.log("ERROR: " + caseId + ": " + (resultDoc.question || "Notification") + " could not be marked as received in cloud. In case of conflict report to ZaMEP, otherwise press Get Data again. " + (JSON.stringify(error)));
                      }
                    }, {
                      doc_ids: [resultDoc._id]
                    });
                  }
                });
              });
            }
          });
        };
      })(this)
    });
  };

  Sync.prototype.replicate = function(options) {
    return $.couch.login({
      name: Coconut.config.get("local_couchdb_admin_username"),
      password: Coconut.config.get("local_couchdb_admin_password"),
      success: function() {
        $.couch.replicate(Coconut.config.cloud_url_with_credentials(), Coconut.config.database_name(), {
          success: function() {
            return options.success();
          },
          error: function(error) {
            return options.error(error);
          }
        }, options.replicationArguments);
        return Coconut.menuView.checkReplicationStatus();
      },
      error: function() {
        return console.log("Unable to login as local admin for replicating the design document (main application)");
      }
    });
  };

  Sync.prototype.replicateApplicationDocs = function(options) {
    return $.ajax({
      dataType: "jsonp",
      url: "" + (Coconut.config.cloud_url_with_credentials()) + "/_design/" + (Coconut.config.design_doc_name()) + "/_view/docIDsForUpdating",
      include_docs: false,
      error: (function(_this) {
        return function(a, b, error) {
          return typeof options.error === "function" ? options.error(error) : void 0;
        };
      })(this),
      success: (function(_this) {
        return function(result) {
          var doc_ids;
          doc_ids = _.pluck(result.rows, "id");
          _this.log("Updating " + doc_ids.length + " docs (users, forms and the design document). Please wait.");
          return _this.replicate(_.extend(options, {
            replicationArguments: {
              doc_ids: doc_ids
            }
          }));
        };
      })(this)
    });
  };

  return Sync;

})(Backbone.Model);
