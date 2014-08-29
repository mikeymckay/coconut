var HierarchyView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

HierarchyView = (function(_super) {
  __extends(HierarchyView, _super);

  function HierarchyView() {
    return HierarchyView.__super__.constructor.apply(this, arguments);
  }

  HierarchyView.prototype.el = '#content';

  HierarchyView.prototype.render = function() {
    this.$el.html("" + (this["class"].name === "GeoHierarchy" ? "This is the format for the hierarchy. Note that a comma must separate every item unless it is the last item in a section. Coconut will warn you and not save if the format is invalid. Copy and paste the contents to <a href='http://jsonlint.com'>jsonlint</a> if you are having trouble getting the formatting correct. <h3>Geo Hierarchy</h3> <pre> REGION: {<br/> DISTRICT: [<br/> SHEHIA<br/> ]<br/> }<br/> </pre>" : "<h3>Facility Hierarchy</h3>") + " <textarea style='width:100%; height:200px;' id='hierarchy_json'> </textarea> <br/> <button id='save' type='button'>Save</button> <div id='message'></div>");
    return $('textarea').val(JSON.stringify(this["class"].hierarchy, void 0, 2));
  };

  HierarchyView.prototype.events = {
    "click #save": "save"
  };

  HierarchyView.prototype.save = function() {
    var error, hierarchy, hierarchy_json;
    hierarchy_json = $("#hierarchy_json").val();
    try {
      JSON.parse(hierarchy_json);
      hierarchy = new this["class"]();
      return hierarchy.fetch({
        success: function() {
          return hierarchy.save("hierarchy", JSON.parse(hierarchy_json));
        },
        error: function() {
          return alert("Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help");
        }
      });
    } catch (_error) {
      error = _error;
      return alert("Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help");
    }
  };

  return HierarchyView;

})(Backbone.View);
