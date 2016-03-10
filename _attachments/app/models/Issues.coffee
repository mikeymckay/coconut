class Issues


  @updateEpidemicAlertsAndAlarmsForLastXDays = (days) =>
    endDate = moment().subtract(days, 'days').format("YYYY-MM-DD")
    days -=1
    console.debug days
    console.debug endDate
    Issues.updateEpidemicAlertsAndAlarms
      endDate: endDate
      error: (error) -> console.error error
      success: (result) =>
        if days > 0
          @updateEpidemicAlertsAndAlarmsForLastXDays(days)
        else
          options?.success?(result)

  @updateEpidemicAlertsAndAlarms = (options) =>
    endDate = options?.endDate   or moment().subtract(2,'days').format("YYYY-MM-DD")

    lookupDistrictThreshold = (district, alarmOrAlert, recurse=false) =>
      if @districtThresholds.data[district] is undefined
        return null if recurse # Stop infinite loops
        lookupDistrictThreshold(GeoHierarchy.alternativeDistrictName(district),alarmOrAlert,true)
      else if @districtThresholds.data[district][moment(endDate).isoWeek()] is undefined
        null
      else
        total: @districtThresholds.data[district][moment(endDate).isoWeek()][alarmOrAlert]

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
      console.debug "ZZZZZ"
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

                        id = "threshold-#{alarmOrAlert}-#{range}-#{locationType}-#{thresholdName.replace("<", "under")}.#{startDate}--#{endDate}.#{locationName}"
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

              # Note that this is inside the thresholds loop so that we have the right amountOfTime and timeUnit
              finished = _.after _(docsToSave).size(), ->
                afterAllThresholdRangesProcessed()

              afterAllThresholdRangesProcessed() if _(docsToSave).size() is 0
              
              _(docsToSave).each (docToSave) ->
                Coconut.database.allDocs
                  # Need to check for any thresholds that ended within x days (7 for weekly) of finding this one. So look for startdates that are 2*x days (14 days) before current startdate since that will put end date within 7 days of the new start date
                  startkey: "threshold-#{docToSave.ThresholdType}-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{moment(docToSave.StartDate).subtract(2*amountOfTime,timeUnit).format('YYYY-MM-DD')}"
                  endkey:   "threshold-#{docToSave.ThresholdType}-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{docToSave.EndDate}"
                  error: (error) -> console.error error
                  success: (result) ->
                    console.debug "Checking for existing thresholds that match #{docToSave._id}"
                    #console.debug "threshold-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{moment(docToSave.StartDate).subtract(2*amountOfTime,timeUnit).format('YYYY-MM-DD')}"
                    #console.debug "threshold-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{docToSave.EndDate}"
                    
                    
                    checkDocs = (docs) ->
                      unless (_(docs).some (doc) ->
                        if doc.id.replace(/.*\.(.+$)/,"$1") is docToSave.LocationName
                          console.debug "MATCH for #{docToSave._id}: #{doc.id}"
                        doc.id.replace(/.*\.(.+$)/,"$1") is docToSave.LocationName
                      )
                        console.debug "NO MATCH for #{docToSave._id}"
                      else
                        delete docsToSave[docToSave._id]
                      finished()
      
                    # Don't create alerts if an alarm is already in place, so need to check for Alarms for the same range
                    if docToSave.ThresholdType is "Alert"
                      Coconut.database.allDocs
                        startkey: "threshold-Alarm-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{moment(docToSave.StartDate).subtract(2*amountOfTime,timeUnit).format('YYYY-MM-DD')}"
                        endkey:   "threshold-Alarm-#{docToSave.Range}-#{docToSave.LocationType}-#{docToSave.ThresholdName.replace("<", "under")}.#{docToSave.EndDate}"
                        error: (error) -> console.error error
                        success: (alarmResultSearch) ->
                          checkDocs(result.rows.concat(alarmResultSearch.rows))
                    else
                      checkDocs(result.rows)






