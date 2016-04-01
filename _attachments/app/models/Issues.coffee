class Issues

  @all = ->
    Coconut.database.allDocs
      startkey: "threshold"
      endkey: "threshold-\ufff0"
      success: (result) ->
        console.log result

  @deleteAllThresholds = ->
    Coconut.database.allDocs
      startkey: "threshold"
      endkey: "threshold-\ufff0"
      include_docs: true
      success: (result) ->
        console.log result
        Coconut.database.bulkRemove
          docs: _(result.rows).pluck "doc"
          error: (error) -> console.error error

  @updateEpidemicAlertsAndAlarmsForLastXDays = (days,options) =>
    endDate = moment().subtract(days, 'days').format("YYYY-MM-DD")
    days -=1
    console.debug days
    Issues.updateEpidemicAlertsAndAlarms
      endDate: endDate
      error: (error) -> console.error error
      success: (result) =>
        if days > 0
          @updateEpidemicAlertsAndAlarmsForLastXDays(days, options)
        else
          console.log "DONE"
          console.log options
          options.success(result)

  @updateEpidemicAlertsAndAlarms = (options) =>
    endDate = options?.endDate   or moment().subtract(2,'days').format("YYYY-MM-DD")
    console.debug endDate

    lookupDistrictThreshold = (district, alarmOrAlert, recurse=false) =>
      if @districtThresholds.data[district] is undefined
        return null if recurse # Stop infinite loops
        lookupDistrictThreshold(GeoHierarchy.alternativeDistrictName(district),alarmOrAlert,true)
      else
        isoWeek = moment(endDate).isoWeek()
        result = @districtThresholds.data[district][isoWeek]
        if @districtThresholds.data[district][isoWeek] is undefined and isoWeek is 53
          if isoWeek is 53
            isoWeek = 52
            result = @districtThresholds.data[district][isoWeek]
          return null if result is undefined
          return total: result[alarmOrAlert]
        else
          total: @districtThresholds.data[district][isoWeek][alarmOrAlert]

    # TODO Consider moving this json into a document in the database
    thresholds = {
      "14-days":
        "Alarm":
          "facility":
            "<5": 10
            "total": 20
          "shehia":
            "<5": 10
            "total": 20
          "village":
            "total": 10
      "7-days":
        "Alarm":
          "district": (district) =>
            lookupDistrictThreshold(district,"alarm")
        "Alert":
          "facility":
            "<5": 5
            "total": 10
          "shehia":
            "<5": 5
            "total": 10
          "village":
            "total": 5
          "district": (district) =>
            lookupDistrictThreshold(district,"alert")
    }

    docsToSave = {}

    afterAllThresholdRangesProcessed = _.after _(thresholds).size(), ->
      Coconut.database.bulkSave {docs: _(docsToSave).values()},
        error: (error) -> console.error error
        success: ->
          console.log docsToSave
          options.success(docsToSave)
    
    # Load the district thresholds so that they can be used in the above function
    Coconut.database.openDoc "district_thresholds",
      error: (error) ->
        console.error error
      success: (result) =>
        @districtThresholds = result

        _(thresholds).each (alarmOrAlertData, range) ->
          [amountOfTime,timeUnit] = range.split(/-/)

          startDate = moment(endDate).subtract(amountOfTime,timeUnit).format("YYYY-MM-DD")

          Reports.positiveCasesAggregated
            startDate: startDate
            endDate: endDate
            ignoreHouseholdNeighborForDistrict: true
            success: (result,allCases) ->

              _(alarmOrAlertData).each (thresholdsForRange, alarmOrAlert) ->
                _(thresholdsForRange).each (categories, locationType) ->
                  _(result[locationType]).each (locationData, locationName) ->
                    if _(categories).isFunction()
                      calculatedCategories = categories(locationName) # Use the above function to lookup the correct district threshold based on the week for the startdate
                      thresholdDescription = "#{alarmOrAlert}: #{locationType} #{locationName} with more than #{Math.floor(parseFloat(calculatedCategories.total))} cases within #{range} during week #{moment(startDate).isoWeek()}"

                    _(calculatedCategories or categories).each (thresholdAmount, thresholdName) ->
                      #console.info "#{locationType}:#{thresholdName} #{locationData[thresholdName].length} > #{thresholdAmount}"
                      if locationData[thresholdName].length > thresholdAmount

                        id = "threshold-#{startDate}--#{endDate}-#{alarmOrAlert}-#{range}-#{locationType}-#{thresholdName.replace("<", "under")}.#{locationName}"
                        docsToSave[id] =
                          _id: id
                          Range: range
                          LocationType: locationType
                          ThresholdName: thresholdName
                          ThresholdType: alarmOrAlert
                          LocationName: locationName
                          District: locationData[thresholdName][0].district
                          StartDate: startDate
                          EndDate: endDate
                          Amount: locationData[thresholdName].length
                          Threshold: thresholdAmount
                          "Threshold Description": thresholdDescription or "#{alarmOrAlert}: #{locationType} with #{thresholdAmount} or more #{thresholdName} cases within #{range}"
                          Description: "#{locationType}: #{locationName}, Cases: #{locationData[thresholdName].length}, Period: #{startDate} - #{endDate}"
                          Links: _(locationData[thresholdName]).pluck "link"
                          "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")
                        docsToSave[id][locationType] = locationName

              # In case of alarm, then remove the alert that was also created
              _(docsToSave).each (docToSave) ->
                if docToSave.ThresholdType is "Alarm"
                  delete docsToSave[docToSave._id.replace(/Alarm/,"Alert")]

              # Note that this is inside the thresholds loop so that we have the right amountOfTime and timeUnit
              Coconut.database.allDocs
                startkey: "threshold-#{moment(startDate).subtract(2*amountOfTime,timeUnit).format("YYYY-MM-DD")}"
                endkey:   "threshold-#{endDate}"
                error: (error) -> console.error error
                success: (result) ->
                  _(docsToSave).each (docToSave) ->
                    #console.debug "Checking for existing thresholds that match #{docToSave._id}"
                    if (_(result.rows).some (existingThreshold) ->
                      # If after removing the date, the ids match, then it's a duplicate
                      existingThresholdIdNoDates = existingThreshold.id.replace(/\d\d\d\d-\d\d-\d\d/g,"")
                      docToSaveIdNoDates = docToSave._id.replace(/\d\d\d\d-\d\d-\d\d/g,"")

                      ###
                      if existingThresholdIdNoDates is docToSaveIdNoDates
                        console.info "***MATCH: \n#{existingThresholdIdNoDates}\n#{docToSaveIdNoDates}"
                      else
                        console.info "NO MATCH: \n#{existingThresholdIdNoDates}\n#{docToSaveIdNoDates}"
                      ###

                      return true if existingThresholdIdNoDates is docToSaveIdNoDates
                      # If an alarm has already been created, don't also create an Alert
                      if docToSave.ThresholdType is "Alert"
                        return true if existingThresholdIdNoDates.replace(/Alarm/,"") is docToSaveIdNoDates.replace(/Alert/,"")
                      return false
                    )
                      delete docsToSave[docToSave._id]
                  
                  afterAllThresholdRangesProcessed()

