var ManageView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ManageView = (function(_super) {
  __extends(ManageView, _super);

  function ManageView() {
    this.render = __bind(this.render, this);
    return ManageView.__super__.constructor.apply(this, arguments);
  }

  ManageView.prototype.el = '#content';

  ManageView.prototype.render = function() {
    this.$el.html("<h1>Manage</h1> <!-- <a href='#sync'>Sync</a> <a href='#configure'>Set cloud vs mobile</a> <a href='#configure'>Set location</a> --> <a href='#users'>Users</a> <a href='#edit/hierarchy/geo'>Shehias</a> <a href='#edit/hierarchy/facility'>Facilities and Facility Mobile Numbers</a> <a href='#edit/data/shehias_received_irs'>Shehias received IRS</a> <a href='#edit/data/shehias_high_risk'>Shehias high risk</a> <a href='#messaging'>Send SMS to users</a> <!-- <h2>Question Sets</h2> <a href='#design'>New</a> <table> <thead> <th></th> <th></th> <th></th> <th></th> </thead> <tbody> </tbody> </table> -->");
    return $("a").button();
  };

  return ManageView;

})(Backbone.View);
