class Issues


  @updateEpidemicAlertsForLastMonth = (options) ->
    Issues.updateEpidemicAlerts
      startDate: moment().subtract(30, 'days').format("YYYY-MM-DD")
      endDate: moment().format("YYYY-MM-DD")
      overwrite: true
      error: (error) -> console.error error
      success: (result) ->
        console.log "Done"
        options?.success?(result)

  @updateEpidemicAlerts = (options) ->

    # Thresholds per facility per week
    thresholdFacility = 10
    thresholdFacilityUnder5s = 5
    thresholdShehia = 10
    thresholdShehiaUnder5 = 5
    thresholdVillage = 5

    docsToSave = {}

    Reports.aggregateWeeklyReports
      startDate: options.startDate
      endDate: options.endDate
      aggregationArea: "Facility"
      aggregationPeriod: "Week"
      facilityType: "All"
      success: (results) =>
        facilitiesOverThresholdByDistrictAndWeek = {}
        _(results.data).each (facilities, week) ->
          _(facilities).each (facilityData, facilityName) ->
            totalCases = facilityData["Mal POS >= 5"] + facilityData["Mal POS < 5"]

            if totalCases  >= thresholdFacility
              district = FacilityHierarchy.getDistrict(facilityName)
              id = "alert-weekly-facility-total-cases-#{week}-#{district}-#{facilityName}"
              docsToSave[id] =
                _id: id
                District: district
                Week: week
                Facility: facilityName
                Amount: totalCases
                Threshold: thresholdFacility
                "Threshold Description": "Facility with #{thresholdFacility} or more cases in one week"
                Description: "Facility #{facilityName}, Cases: #{totalCases}, Week: #{week}"
                Links: ["#show/weeklyReport/#{week}-#{GeoHierarchy.getZoneForDistrict(district)}-#{district}-#{facilityName}"]
                "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")


            if facilityData["Mal POS < 5"] >= thresholdFacilityUnder5s
              id = "alert-weekly-facility-under-5-cases#{week}-#{district}-#{facilityName}"
              amount = facilityData["Mal POS < 5"]

              docsToSave[id] =
                _id: id
                District: FacilityHierarchy.getDistrict(facilityName)
                Week: week
                Facility: facilityName
                Amount: amount
                Threshold: thresholdFacilityUnder5s
                "Threshold Description": "Facility with #{thresholdFacilityUnder5s} or more cases in under 5s in one week"
                Description: "Facility #{facilityName}, < 5 Cases: #{amount}, Week: #{week}"
                Links: ["#show/weeklyReport/#{week}"]
                "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")


        Reports.positiveCasesByDistrictAreaAndAge
          startDate: options.startDate
          endDate: options.endDate
          aggregationArea: "shehia"
          aggregationPeriod: "Week"
          success: (byShehia,cases) ->
            _(byShehia).each (weeks, district) ->
              _(weeks).each (shehias, week) ->
                _(shehias).each (ages, shehia) ->

                  if (ages[">=5"].length + ages["<5"].length) >= thresholdShehia
                    id = "alert-weekly-shehia-cases-#{week}-#{district}-#{shehia}"
                    amount = ages[">=5"].length + ages["<5"].length
                    docsToSave[id] =
                      _id: id
                      District: district
                      Week: week
                      Shehia: shehia
                      Amount: amount
                      Cases: _(ages[">=5"].concat(ages["<5"])).pluck "caseID"
                      Links: _(ages[">=5"].concat(ages["<5"])).pluck "link"
                      Threshold: thresholdShehia
                      "Threshold Description": "Shehia with #{thresholdShehia} or more cases in one week"
                      Description: "Shehia #{shehia}, Cases: #{amount}, Week: #{week}"
                      "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")

                  else if ages["<5"].length >= thresholdShehiaUnder5
                    id = "alert-weekly-shehia-under-5-cases-#{week}-#{district}-#{shehia}"
                    amount = ages["<5"].length
                    docsToSave[id] =
                      _id: id
                      District: district
                      Week: week
                      Shehia: shehia
                      Amount: amount
                      Cases: _(ages["<5"]).pluck "caseID"
                      Threshold: thresholdShehiaUnder5
                      "Threshold Description": "Shehia with #{thresholdShehiaUnder5} or more cases in under 5s in one week"
                      Description: "Shehia #{shehia}, < 5 Cases: #{amount}, Week: #{week}"
                      "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")

            Reports.positiveCasesByDistrictAreaAndAge
              cases: cases
              aggregationArea: "village"
              aggregationPeriod: "Week"
              success: (byVillage) ->
                _(byVillage).each (weeks, district) ->
                  _(weeks).each (villages, week) ->
                    _(villages).each (ages, village) ->
                      if (ages[">=5"].length + ages["<5"].length) >= thresholdVillage
                        id = "alert-weekly-village-cases-#{week}-#{district}-#{village}"
                        amount = ages[">=5"].length + ages["<5"].length
                        docsToSave[id] =
                          _id: id
                          District: district
                          Week: week
                          Village: village
                          Amount: amount
                          Cases: _(ages[">=5"].concat(ages["<5"])).pluck "caseID"
                          Links: _(ages[">=5"].concat(ages["<5"])).pluck "link"
                          Threshold: thresholdVillage
                          "Threshold Description": "Village with  #{thresholdVillage} or more cases in one week"
                          Description: "Village #{village}, Cases: #{amount}, Week: #{week}"
                          "Date Created": moment().format("YYYY-MM-DD HH:mm:ss")


                Coconut.database.allDocs
                  keys: _(docsToSave).keys()
                  include_docs: options.overwrite? and options.overwrite
                  error: (error) -> console.error error
                  success: (result) ->
                    _(result.rows).each (row) ->
                      if docsToSave[row.id] and not options["overwrite"]
                        console.log "#{row.id} exists - not updating it"
                        delete docsToSave[row.id]
                      if docsToSave[row.id] and options["overwrite"] and row.doc isnt null
                        docsToSave[row.id]["_rev"] = row.doc._rev

                    console.log docsToSave

                    if _(docsToSave).size() isnt 0
                      Coconut.database.bulkSave
                        docs:_(docsToSave).toArray()
                        error: (error) -> console.error error
                        success: (result) ->
                          options?.success?(result)
                    else
                      options?.success?("No issues to save")


  @updateEpidemicAlarms = (options) ->
    alerts = [
      "alert-weekly-facility-total-cases"
      "alert-weekly-facility-under-5-cases"
      "alert-weekly-shehia-cases"
      "alert-weekly-shehia-under-5-cases"
      "alert-weekly-village-cases"
    ]

    startDate = moment(options.startDate)
    startYear = startDate.format("GGGG") # ISO week year
    startWeek =startDate.format("WW")
    endDate = moment(options.endDate).endOf("day")
    endYear = endDate.format("GGGG")
    endWeek = endDate.format("WW")

    finished = _.after alerts.length, ->
      options?.success?()

    _(alerts).each (alert) ->
      Coconut.database.allDocs
        startkey: "#{alert}-#{startYear}-#{startWeek}"
        endkey: "#{alert}-#{endYear}-#{endWeek}-\ufff0"
        include_docs: false
        error: (error) -> console.log error
        success: (result) ->
          alertsByLocationAndDate = {}
          alarms = {}
          _(result.rows).each (row) ->
            [ignore,type, date, location] = row.id.match(/alert-(.*)-(20\d\d-\d\d)-(.*)/)
            alertsByLocationAndDate[location] = {} unless alertsByLocationAndDate[location]
            alertsByLocationAndDate[location][date] = row.id

          _(alertsByLocationAndDate).each (alert, location) ->
            alertWeek = moment(alert[location])
            duration=1
            if alertsByLocationAndDate[location][alertWeek.add(duration,'week')]
              alarms[type][date][location].push row.id
              alarms[type][date][location].push alertsByLocationAndDate





