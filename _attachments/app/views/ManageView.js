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
    this.$el.html("<!-- <a href='#sync'>Sync</a> <a href='#configure'>Set cloud vs mobile</a> <a href='#configure'>Set location</a> --> <a href='#users'>Manage users</a> <a href='#messaging'>Send message to users</a> <a href='#edit/hierarchy/geo'>Edit Geo Hierarchy (District,Shehias, etc)</a> <a href='#edit/hierarchy/facility'>Edit Facility Hierarchy</a> <!-- <h2>Question Sets</h2> <a href='#design'>New</a> <table> <thead> <th></th> <th></th> <th></th> <th></th> </thead> <tbody> </tbody> </table> -->");
    return $("a").button();
  };

  return ManageView;

})(Backbone.View);
