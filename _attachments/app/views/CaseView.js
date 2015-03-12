var CaseView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

CaseView = (function(_super) {
  __extends(CaseView, _super);

  function CaseView() {
    this.createObjectTable = __bind(this.createObjectTable, this);
    this.render = __bind(this.render, this);
    return CaseView.__super__.constructor.apply(this, arguments);
  }

  CaseView.prototype.el = '#content';

  CaseView.prototype.render = function(scrollTargetID) {
    var tables;
    Coconut["case"] = this["case"];
    this.$el.html("<style> table.tablesorter {font-size: 125%} </style> <h1>Case ID: " + (this["case"].MalariaCaseID()) + "</h1> <h3>Last Modified: " + (this["case"].LastModifiedAt()) + "</h3> <h3>Questions: " + (this["case"].Questions()) + "</h3>");
    tables = ["USSD Notification", "Case Notification", "Facility", "Household", "Household Members"];
    this.$el.append(_.map(tables, (function(_this) {
      return function(tableType) {
        if (_this["case"][tableType] != null) {
          if (tableType === "Household Members") {
            return _.map(_this["case"][tableType], function(householdMember) {
              return _this.createObjectTable(tableType, householdMember);
            }).join("");
          } else {
            return _this.createObjectTable(tableType, _this["case"][tableType]);
          }
        }
      };
    })(this)).join(""));
    _.each($('table tr'), function(row, index) {
      if (index % 2 === 1) {
        return $(row).addClass("odd");
      }
    });
    if (scrollTargetID != null) {
      return $('html, body').animate({
        scrollTop: $("#" + scrollTargetID).offset().top
      }, 'slow');
    }
  };

  CaseView.prototype.createObjectTable = function(name, object) {
    return "<h2 id=" + object._id + ">" + name + " <small><a href='#edit/result/" + object._id + "'>Edit</a></small></h2> <table class='tablesorter'> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody> " + (_.map(object, function(value, field) {
      if (("" + field).match(/_id|_rev|collection/)) {
        return;
      }
      return "<tr> <td>" + field + "</td><td>" + value + "</td> </tr>";
    }).join("")) + " </tbody> </table>";
  };

  return CaseView;

})(Backbone.View);
