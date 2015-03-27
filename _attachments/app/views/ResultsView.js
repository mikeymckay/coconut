var ResultsView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

ResultsView = (function(_super) {
  __extends(ResultsView, _super);

  function ResultsView() {
    this.render = __bind(this.render, this);
    return ResultsView.__super__.constructor.apply(this, arguments);
  }

  ResultsView.prototype.initialize = function() {
    return this.question = new Question();
  };

  ResultsView.prototype.el = '#content';

  ResultsView.prototype.render = function() {
    this.$el.html(("<style> table.results th.header, table.results td{ font-size:150%; } .dataTables_wrapper .dataTables_length{ display: none; } .dataTables_filter input{ display:inline; width:300px; } a[role=button]{ background-color: white; margin-right:5px; -moz-border-radius: 1em; -webkit-border-radius: 1em; border: solid gray 1px; font-family: Helvetica,Arial,sans-serif; font-weight: bold; color: #222; text-shadow: 0 1px 0 #fff; -webkit-background-clip: padding-box; -moz-background-clip: padding; background-clip: padding-box; padding: .6em 20px; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; position: relative; zoom: 1; } a[role=button].paginate_disabled_previous, a[role=button].paginate_disabled_next{ color:gray; } .dataTables_info{ float:right; } .dataTables_paginate{ margin-bottom:20px; } </style> <a href='#new/result/" + (escape(this.question.id)) + "'>Add new '" + this.question.id + "'</a> <div class='not-complete' data-collapsed='false' data-role='collapsible'> <h2>'" + this.question.id + "' Items Not Completed (<span class='count-complete-false'></span>)</h2> <table class='results complete-false tablesorter'> <thead><tr>") + _.map(this.question.summaryFieldNames(), function(summaryField) {
      return "<th class='header'>" + summaryField + "</th>";
    }).join("") + "<th></th> </tr></thead> <tbody> </tbody> <tfoot><tr>" + _.map(this.question.summaryFieldNames(), function(summaryField) {
      return "<th class='header'>" + summaryField + "</th>";
    }).join("") + ("<th></th> </tr></tfoot> </table> </div> <div class='complete' data-role='collapsible'> <h2>'" + this.question.id + "' Items Completed (or transferred out) (<span class='count-complete-true'></span>)</h2> <table class='results complete-true tablesorter'> <thead><tr>") + _.map(this.question.summaryFieldNames(), function(summaryField) {
      return "<th class='header'>" + summaryField + "</th>";
    }).join("") + "<th></th> </tr></thead> <tbody> </tbody> <tfoot><tr>" + _.map(this.question.summaryFieldNames(), function(summaryField) {
      return "<th class='header'>" + summaryField + "</th>";
    }).join("") + "<th></th> </tr></tfoot> </table> </div>");
    $("a").button();
    $('[data-role=collapsible]').collapsible();
    $('.complete').bind("expand", (function(_this) {
      return function() {
        return _this.loadResults("true");
      };
    })(this));
    this.loadResults("false");
    return this.updateCountComplete();
  };

  ResultsView.prototype.updateCountComplete = function() {
    var results;
    results = new ResultCollection();
    return results.fetch({
      question: this.question.id,
      isComplete: "true",
      success: (function(_this) {
        return function() {
          return $(".count-complete-true").html(results.length);
        };
      })(this)
    });
  };

  ResultsView.prototype.loadResults = function(complete) {
    var results;
    results = new ResultCollection();
    return results.fetch({
      include_docs: "true",
      question: this.question.id,
      isComplete: complete,
      success: (function(_this) {
        return function() {
          $(".count-complete-" + complete).html(results.length);
          results.each(function(result, index) {
            if (complete !== "true" && result.wasTransferredOut()) {
              $(".count-complete-" + complete).html(parseInt($(".count-complete-" + complete).html()) - 1);
              return;
            }
            $("table.complete-" + complete + " tbody").append("<tr> " + (_.map(result.summaryValues(_this.question), function(value) {
              return "<td><a href='#edit/result/" + result.id + "'>" + value + "</a></td>";
            }).join("")) + " <td><a href='#delete/result/" + result.id + "' data-icon='delete' data-iconpos='notext'>Delete</a></td> </tr>");
            if (index + 1 === results.length) {
              $("table a").button();
              $("table").trigger("update");
            }
            return _.each($('table tr'), function(row, index) {
              if (index % 2 === 1) {
                return $(row).addClass("odd");
              }
            });
          });
          $('table').dataTable();
          return $(".dataTables_filter input").textinput();
        };
      })(this)
    });
  };

  return ResultsView;

})(Backbone.View);
