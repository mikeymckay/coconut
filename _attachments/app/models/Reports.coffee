class Reports

  positiveCaseLocations: (options) ->

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/positiveCaseLocations",
      success: (result) ->
        locations = []
        for currentLocation,currentLocationIndex in result.rows
          currentLocation = currentLocation.value
          locations[currentLocation] =
            100:[]
            1000:[]
            5000:[]
            10000:[]

          for loc, locIndex in result.rows
            continue if locIndex is currentLocationIndex
            loc = loc.value
            distanceInMeters = (new LatLon(currentLocation[0],currentLocation[1])).distanceTo(new LatLon(loc[0],loc[1])) * 1000
            if distanceInMeters<100
              locations[currentLocation][100].push loc
            else if distanceInMeters<1000
              locations[currentLocation][1000].push loc
            else if distanceInMeters<5000
              locations[currentLocation][5000].push loc
            else if distanceInMeters<10000
              locations[currentLocation][10000].push loc

        options.success(locations)

  positiveCaseClusters: () ->
    @positiveCaseLocations
      success: (positiveCases) ->
        for positiveCase, cluster of positiveCases
          #if (cluster[100].length + cluster[1000].length) > 4
          #  console.log (cluster[100].length + cluster[1000].length)
          if (cluster[100].length) > 4
            console.log "#{cluster[100].length} cases within 100 meters of one another"


  getCases: (options) =>
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/caseIDsByDate",
      # Note that these seem reversed due to descending order
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get "date_format")
      endkey: options.startDate
      descending: true
      include_docs: false
      success: (result) =>
        caseIDs = _.unique(_.pluck result.rows, "value")

        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
          keys: caseIDs
          include_docs: true
          success: (result) =>
            groupedResults = _.chain(result.rows)
              .groupBy (row) =>
                row.key
              .map (resultsByCaseID) =>
                malariaCase = new Case
                  results: _.pluck resultsByCaseID, "doc"
                if options.mostSpecificLocation.name is "ALL" or malariaCase.withinLocation(options.mostSpecificLocation)
                  return malariaCase
              .compact()
              .value()
            options.success groupedResults
          error: =>
            options?.error()

  casesAggregatedForAnalysis: (options) =>

    data = {}

    # Hack required because we have multiple success callbacks
    options.finished = options.success

    @getCases _.extend options,
      success: (cases) =>
        IRSThresholdInMonths = 6
  
        data.followupsByDistrict = {}
        data.passiveCasesByDistrict = {}
        data.agesByDistrict = {}
        data.genderByDistrict = {}
        data.netsAndIRSByDistrict = {}
        data.travelByDistrict = {}
        data.totalPositiveCasesByDistrict = {}

        # Setup hashes for each table
        districts = GeoHierarchy.allDistricts()
        districts.push("UNKNOWN")
        districts.push("ALL")
        _.each districts, (district) ->
          data.followupsByDistrict[district] =
            allCases: []
            casesFollowedUp: []
            casesNotFollowedUp: []
            missingUssdNotification: []
            missingCaseNotification: []
          data.passiveCasesByDistrict[district] =
            indexCases: []
            householdMembers: []
            passiveCases: []
          data.agesByDistrict[district] =
            underFive: []
            fiveToFifteen: []
            fifteenToTwentyFive: []
            overTwentyFive: []
            unknown: []
          data.genderByDistrict[district] =
            male: []
            female: []
            unknown: []
          data.netsAndIRSByDistrict[district] =
            sleptUnderNet: []
            recentIRS: []
          data.travelByDistrict[district] =
            travelReported: []
          data.totalPositiveCasesByDistrict[district] = []

        _.each cases, (malariaCase) ->

          district = malariaCase.district() || "UNKNOWN"

          data.followupsByDistrict[district].allCases.push malariaCase
          data.followupsByDistrict["ALL"].allCases.push malariaCase
            
          if malariaCase["Household"]?.complete is "true"
            data.followupsByDistrict[district].casesFollowedUp.push malariaCase
            data.followupsByDistrict["ALL"].casesFollowedUp.push malariaCase
          else
            data.followupsByDistrict[district].casesNotFollowedUp.push malariaCase
            data.followupsByDistrict["ALL"].casesNotFollowedUp.push malariaCase

          unless malariaCase["USSD Notification"]?
            data.followupsByDistrict[district].missingUssdNotification.push malariaCase
            data.followupsByDistrict["ALL"].missingUssdNotification.push malariaCase
          unless malariaCase["Case Notification"]?
            data.followupsByDistrict[district].missingCaseNotification.push malariaCase
            data.followupsByDistrict["ALL"].missingCaseNotification.push malariaCase

          # This is our current definition of a case that has been followed up
          # TODO - how do we deal with households that are incomplete but that have complete household members
          if malariaCase["Household"]?.complete is "true"
            data.passiveCasesByDistrict[district].indexCases.push malariaCase
            data.passiveCasesByDistrict["ALL"].indexCases.push malariaCase

            if malariaCase["Household Members"]?
              completedHouseholdMembers = _.where(malariaCase["Household Members"], {complete:"true"})
              data.passiveCasesByDistrict[district].householdMembers =  data.passiveCasesByDistrict[district].householdMembers.concat(completedHouseholdMembers)
              data.passiveCasesByDistrict["ALL"].householdMembers =  data.passiveCasesByDistrict["ALL"].householdMembers.concat(completedHouseholdMembers)

            positiveCasesAtHousehold = malariaCase.positiveCasesAtHousehold()
            data.passiveCasesByDistrict[district].passiveCases = data.passiveCasesByDistrict[district].passiveCases.concat positiveCasesAtHousehold
            data.passiveCasesByDistrict["ALL"].passiveCases = data.passiveCasesByDistrict["ALL"].passiveCases.concat positiveCasesAtHousehold

            _.each malariaCase.positiveCasesIncludingIndex(), (positiveCase) ->
              data.totalPositiveCasesByDistrict[district].push positiveCase
              data.totalPositiveCasesByDistrict["ALL"].push positiveCase

              if positiveCase.Age?
                age = parseInt(positiveCase.Age)
                if age < 5
                  data.agesByDistrict[district].underFive.push positiveCase
                  data.agesByDistrict["ALL"].underFive.push positiveCase
                else if age < 15
                  data.agesByDistrict[district].fiveToFifteen.push positiveCase
                  data.agesByDistrict["ALL"].fiveToFifteen.push positiveCase
                else if age < 25
                  data.agesByDistrict[district].fifteenToTwentyFive.push positiveCase
                  data.agesByDistrict["ALL"].fifteenToTwentyFive.push positiveCase
                else if age >= 25
                  data.agesByDistrict[district].overTwentyFive.push positiveCase
                  data.agesByDistrict["ALL"].overTwentyFive.push positiveCase
              else
                data.agesByDistrict[district].unknown.push positiveCase unless positiveCase.age
                data.agesByDistrict["ALL"].unknown.push positiveCase unless positiveCase.age
    
              if positiveCase.Sex is "Male"
                data.genderByDistrict[district].male.push positiveCase
                data.genderByDistrict["ALL"].male.push positiveCase
              else if positiveCase.Sex is "Female"
                data.genderByDistrict[district].female.push positiveCase
                data.genderByDistrict["ALL"].female.push positiveCase
              else
                data.genderByDistrict[district].unknown.push positiveCase
                data.genderByDistrict["ALL"].unknown.push positiveCase

              if (positiveCase.SleptunderLLINlastnight is "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight is "Yes")
                data.netsAndIRSByDistrict[district].sleptUnderNet.push positiveCase
                data.netsAndIRSByDistrict["ALL"].sleptUnderNet.push positiveCase

              if (positiveCase.LastdateofIRS and positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/))
                # if date of spraying is less than X months
                if (new moment).subtract('months',Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))
                  data.netsAndIRSByDistrict[district].recentIRS.push positiveCase
                  data.netsAndIRSByDistrict["ALL"].recentIRS.push positiveCase
                
              if (positiveCase.TravelledOvernightinpastmonth?.match(/yes/i) || positiveCase.OvernightTravelinpastmonth?.match(/yes/i))
                data.travelByDistrict[district].travelReported.push positiveCase
                data.travelByDistrict["ALL"].travelReported.push positiveCase

        options.finished(data)




  @systemErrors: (options) ->

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/errorsByDate",
      # Note that these seem reversed due to descending order
      startkey: options?.endDate || moment().format("YYYY-MM-DD")
      endkey: options?.startDate || moment().subtract('days',1).format("YYYY-MM-DD")
      descending: true
      include_docs: true
      success: (result) ->
        errorsByType = {}
        _.chain(result.rows)
          .pluck("doc")
          .each (error) ->
            if errorsByType[error.message]?
              errorsByType[error.message].count++
            else
              errorsByType[error.message]= {}
              errorsByType[error.message].count = 0
              errorsByType[error.message]["Most Recent"] = error.datetime
              errorsByType[error.message]["Source"] = error.source

            errorsByType[error.message]["Most Recent"] = error.datetime if errorsByType[error.message]["Most Recent"] < error.datetime
        options.success(errorsByType)

  @notFollowedUp: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract('days',9).format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract('days',2).format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        console.log cases
        options.success(cases.followupsByDistrict["ALL"]?.casesNotFollowedUp)

  @unknownDistricts: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract('days',14).format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract('days',7).format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        options.success(cases.followupsByDistrict["UNKNOWN"]?.casesNotFollowedUp)
