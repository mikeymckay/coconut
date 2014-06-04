var FacilityHierarchy,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

FacilityHierarchy = (function(_super) {
  __extends(FacilityHierarchy, _super);

  function FacilityHierarchy() {
    return FacilityHierarchy.__super__.constructor.apply(this, arguments);
  }

  FacilityHierarchy.prototype.initialize = function() {
    return this.set({
      _id: "Facility Hierarchy"
    });
  };

  FacilityHierarchy.prototype.url = "/facilityHierarchy";

  FacilityHierarchy.load = function(options) {
    var facilityHierarchy;
    facilityHierarchy = new FacilityHierarchy();
    return facilityHierarchy.fetch({
      success: function() {
        FacilityHierarchy.hierarchy = facilityHierarchy.get("hierarchy");
        return options.success();
      },
      error: function(error) {
        console.error("Error loading Facility Hierarchy: " + (JSON.stringify(error)));
        return options.error(error);
      }
    });
  };

  FacilityHierarchy.allFacilities = function() {
    return _.chain(FacilityHierarchy.hierarchy).flatten().values().pluck("facility").value();
  };

  FacilityHierarchy.getDistrict = function(facility) {
    var result;
    result = null;
    _.each(FacilityHierarchy.hierarchy, function(facilityData, district) {
      if (_.chain(facilityData).pluck("facility").contains(facility).value()) {
        return result = district;
      }
    });
    return result;
  };

  return FacilityHierarchy;

})(Backbone.Model);
