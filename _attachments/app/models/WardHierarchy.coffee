# This is kind of strange
# We initialize this, then fetch it, then set the hierarchy property to the hierarchy attribute
# This was a quick fix - a bit of code debt probably
###
wardHierarchy = new WardHierarchy()
wardHierarchy.fetch
  success: ->
    WardHierarchy.hierarchy = wardHierarchy.get("hierarchy")
    Backbone.history.start()
  error: (error) ->
    console.error "Error loading Ward Hierarchy: #{error}"
###
#
class WardHierarchy extends Backbone.Model
  initialize: ->
    @set
      _id: "Ward Hierarchy"

  url: "/wardHierarchy"

# ward_shehia_breakdown_by_constituan_district_region

#        "REGION": {
#            "DISTRICT": {
#                "CONSTITUAN": [
#                    "WARD/ Shehia"
#                ]
#            }
#        },
#
#

  WardHierarchy.byWard = (targetWard) ->
    result = {}
    _.each WardHierarchy.hierarchy, (districts,region) ->
      _.each districts, (constituans,district) ->
        _.each constituans, (wards,constituan) ->
          _.each wards, (ward) ->
            if ward is targetWard
              result = {
                region: region
                district: district
                constituan: constituan
              }
    return result

  WardHierarchy.region = (ward) ->
    return unless ward?
    WardHierarchy.byWard(ward.toUpperCase()).region

  WardHierarchy.district = (ward) ->
    return unless ward?
    WardHierarchy.byWard(ward.toUpperCase()).district

  WardHierarchy.constituan = (ward) ->
    return unless ward?
    WardHierarchy.byWard(ward.toUpperCase()).constituan

  WardHierarchy.ward = (ward) ->
    ward

  WardHierarchy.shehia = (shehia) ->
    shehia

  WardHierarchy.allRegions = ->
    _.sortBy(_.keys(WardHierarchy.hierarchy), (region) -> region)

  WardHierarchy.allDistricts = ->
    _.chain(
      _.map WardHierarchy.hierarchy, (districts,region) ->
        _.keys districts
    )
    .flatten()
    .sortBy((district) -> district)
    .value()

  WardHierarchy.allConstituans = ->
    _.chain(
      _.map WardHierarchy.hierarchy, (districts,region) ->
        _.map districts, (constituans,district) ->
          _.keys constituans
    )
    .flatten()
    .sortBy((constituan) -> constituan)
    .value()

  WardHierarchy.allWards = (options = {}) ->
    _.chain(
      _.map WardHierarchy.hierarchy, (districts,region) ->
        if options.region
          return unless region is options.region
        _.map districts, (constituans,district) ->
          if options.district
            return unless district is options.district
          _.map constituans, (wards,constituan) ->
            if options.constituan
              return unless constituan is options.constituan
            wards
    )
    .flatten()
    .compact()
    .sortBy((ward) -> ward)
    .value()
