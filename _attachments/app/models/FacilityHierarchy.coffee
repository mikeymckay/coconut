class FacilityHierarchy extends Backbone.Model

  initialize: ->
    @set
      _id: "Facility Hierarchy"

  url: "/facilityHierarchy"

  #Note that the facilities after the line break are hospitals


  FacilityHierarchy.load = (options) ->
    facilityHierarchy = new FacilityHierarchy()
    facilityHierarchy.fetch
      success: ->
        FacilityHierarchy.hierarchy = facilityHierarchy.get("hierarchy")
        options.success()
      error: (error) ->
        console.error "Error loading Facility Hierarchy: #{JSON.stringify(error)}"
        options.error(error)

  FacilityHierarchy.allDistricts = ->
    _.keys(FacilityHierarchy.hierarchy).sort()

  FacilityHierarchy.allFacilities = ->
    _.chain(FacilityHierarchy.hierarchy).values().flatten().pluck("facility").value()

  FacilityHierarchy.getDistrict = (facility) ->
    result = null
    _.each FacilityHierarchy.hierarchy, (facilityData,district) ->
      if _.chain(facilityData).pluck("facility").contains(facility).value()
        result = district
    return result
