var FacilityHierarchy,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

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

  FacilityHierarchy.allDistricts = function() {
    return _.keys(FacilityHierarchy.hierarchy).sort();
  };

  FacilityHierarchy.allFacilities = function() {
    return _.chain(FacilityHierarchy.hierarchy).values().flatten().pluck("facility").value();
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

  FacilityHierarchy.getZone = function(facility) {
    var district, districtHierarchy, region;
    district = FacilityHierarchy.getDistrict(facility);
    districtHierarchy = GeoHierarchy.find(district, "DISTRICT");
    if (districtHierarchy.length === 1) {
      region = GeoHierarchy.find(district, "DISTRICT")[0].REGION;
      if (region.match(/PEMBA/)) {
        return "PEMBA";
      } else {
        return "UNGUJA";
      }
    }
    return null;
  };

  FacilityHierarchy.facilities = function(district) {
    return _.pluck(FacilityHierarchy.hierarchy[district], "facility");
  };

  FacilityHierarchy.numbers = function(district, facility) {
    var foundFacility;
    foundFacility = _(FacilityHierarchy.hierarchy[district]).find(function(result) {
      return result.facility === facility;
    });
    return foundFacility["mobile_numbers"];
  };

  FacilityHierarchy.update = function(district, targetFacility, numbers, options) {
    var facilityHierarchy, facilityIndex;
    console.log(numbers);
    facilityIndex = -1;
    _(FacilityHierarchy.hierarchy[district]).find(function(facility) {
      facilityIndex++;
      return facility['facility'] === targetFacility;
    });
    if (facilityIndex === -1) {
      FacilityHierarchy.hierarchy[district].push({
        facility: targetFacility,
        mobile_numbers: numbers
      });
    } else {
      FacilityHierarchy.hierarchy[district][facilityIndex] = {
        facility: targetFacility,
        mobile_numbers: numbers
      };
    }
    facilityHierarchy = new FacilityHierarchy();
    return facilityHierarchy.fetch({
      error: function(error) {
        return console.error(JSON.stringify(error));
      },
      success: function(result) {
        return facilityHierarchy.save("hierarchy", FacilityHierarchy.hierarchy, {
          error: function(error) {
            return console.error(JSON.stringify(error));
          },
          success: function() {
            Coconut.debug("FacilityHierarchy saved");
            return FacilityHierarchy.load({
              error: function(error) {
                return console.error(JSON.stringify(error));
              },
              success: function() {
                return options != null ? options.success() : void 0;
              }
            });
          }
        });
      }
    });
  };

  return FacilityHierarchy;

})(Backbone.Model);
