class Issues

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
                district: district
                week: week
                facility: facilityName
                amount: totalCases
                threshold: thresholdFacility
                thresholdDescription: "Facility with #{thresholdFacility} or more cases in one week"
                description: "Facility #{facilityName}, Cases: #{totalCases}, Week: #{week}"
                links: ["#show/weeklyReport/#{week}-#{GeoHierarchy.getZoneForDistrict(district)}-#{district}-#{facilityName}"]

            if facilityData["Mal POS < 5"] >= thresholdFacilityUnder5s
              id = "alert-weekly-facility-under-5-cases#{week}-#{district}-#{facilityName}"
              amount = facilityData["Mal POS < 5"]

              docsToSave[id] =
                _id: id
                district: FacilityHierarchy.getDistrict(facilityName)
                week: week
                facility: facilityName
                amount: amount
                threshold: thresholdFacilityUnder5s
                thresholdDescription: "Facility with #{thresholdFacilityUnder5s} or more cases in under 5s in one week"
                description: "Facility #{facilityName}, < 5 Cases: #{amount}, Week: #{week}"
                links: ["#show/weeklyReport/#{week}"]


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
                      district: district
                      week: week
                      shehia: shehia
                      amount: amount
                      cases: _(ages[">=5"].concat(ages["<5"])).pluck "caseID"
                      links: _(ages[">=5"].concat(ages["<5"])).pluck "link"
                      threshold: thresholdShehia
                      thresholdDescription: "Shehia with #{thresholdShehia} or more cases in one week"
                      description: "Shehia #{shehia}, Cases: #{amount}, Week: #{week}"

                  else if ages["<5"].length >= thresholdShehiaUnder5
                    id = "alert-weekly-shehia-under-5-cases-#{week}-#{district}-#{shehia}"
                    amount = ages["<5"].length
                    docsToSave[id] =
                      _id: id
                      district: district
                      week: week
                      shehia: shehia
                      amount: amount
                      cases: _(ages["<5"]).pluck "caseID"
                      threshold: thresholdShehiaUnder5
                      thresholdDescription: "Shehia with #{thresholdShehiaUnder5} or more cases in under 5s in one week"
                      description: "Shehia #{shehia}, < 5 Cases: #{amount}, Week: #{week}"

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
                          district: district
                          week: week
                          village: village
                          amount: amount
                          cases: _(ages[">=5"].concat(ages["<5"])).pluck "caseID"
                          links: _(ages[">=5"].concat(ages["<5"])).pluck "link"
                          threshold: thresholdVillage
                          thresholdDescription: "Village with  #{thresholdVillage} or more cases in one week"
                          description: "Village #{village}, Cases: #{amount}, Week: #{week}"


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
                          options?.success?()
                    else
                      options?.success?()


