class Reports

  positiveCaseLocations: (options) ->

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/positiveCaseLocations",
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get "date_format")
      endkey: options.startDate
      descending: true
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

  positiveCaseClusters: (options) ->
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

    options.aggregationLevel

    # Hack required because we have multiple success callbacks
    options.finished = options.success

    @getCases _.extend options,
      success: (cases) =>
        IRSThresholdInMonths = 6
  
        data.followups = {}
        data.passiveCases = {}
        data.ages = {}
        data.gender = {}
        data.netsAndIRS = {}
        data.travel = {}
        data.totalPositiveCases = {}

        # Setup hashes for each table
        aggregationNames = GeoHierarchy.all options.aggregationLevel
        aggregationNames.push("UNKNOWN")
        aggregationNames.push("ALL")
        _.each aggregationNames, (aggregationName) ->
          data.followups[aggregationName] =
            allCases: []
            casesWithCompleteFacilityVisit: []
            casesWithoutCompleteFacilityVisit: []
            casesWithCompleteHouseholdVisit: []
            casesWithoutCompleteHouseholdVisit: []
            missingUssdNotification: []
            missingCaseNotification: []
          data.passiveCases[aggregationName] =
            indexCases: []
            householdMembers: []
            passiveCases: []
          data.ages[aggregationName] =
            underFive: []
            fiveToFifteen: []
            fifteenToTwentyFive: []
            overTwentyFive: []
            unknown: []
          data.gender[aggregationName] =
            male: []
            female: []
            unknown: []
          data.netsAndIRS[aggregationName] =
            sleptUnderNet: []
            recentIRS: []
          data.travel[aggregationName] =
            travelReported: []
          data.totalPositiveCases[aggregationName] = []

        _.each cases, (malariaCase) ->
          caseLocation = malariaCase.locationBy(options.aggregationLevel) || "UNKNOWN"

          data.followups[caseLocation].allCases.push malariaCase
          data.followups["ALL"].allCases.push malariaCase

          if malariaCase["Facility"]?.complete is "true"
            data.followups[caseLocation].casesWithCompleteFacilityVisit.push malariaCase
            data.followups["ALL"].casesWithCompleteFacilityVisit.push malariaCase
          else
            data.followups[caseLocation].casesWithoutCompleteFacilityVisit.push malariaCase
            data.followups["ALL"].casesWithoutCompleteFacilityVisit.push malariaCase
            
          if malariaCase["Household"]?.complete is "true"
            data.followups[caseLocation].casesWithCompleteHouseholdVisit.push malariaCase
            data.followups["ALL"].casesWithCompleteHouseholdVisit.push malariaCase
          else
            data.followups[caseLocation].casesWithoutCompleteHouseholdVisit.push malariaCase
            data.followups["ALL"].casesWithoutCompleteHouseholdVisit.push malariaCase

          unless malariaCase["USSD Notification"]?
            data.followups[caseLocation].missingUssdNotification.push malariaCase
            data.followups["ALL"].missingUssdNotification.push malariaCase
          unless malariaCase["Case Notification"]?
            data.followups[caseLocation].missingCaseNotification.push malariaCase
            data.followups["ALL"].missingCaseNotification.push malariaCase

          # This is our current definition of a case that has been followed up
          # TODO - how do we deal with households that are incomplete but that have complete household members
          if malariaCase["Household"]?.complete is "true"
            data.passiveCases[caseLocation].indexCases.push malariaCase
            data.passiveCases["ALL"].indexCases.push malariaCase

            if malariaCase["Household Members"]?
              completedHouseholdMembers = _.where(malariaCase["Household Members"], {complete:"true"})
              data.passiveCases[caseLocation].householdMembers =  data.passiveCases[caseLocation].householdMembers.concat(completedHouseholdMembers)
              data.passiveCases["ALL"].householdMembers =  data.passiveCases["ALL"].householdMembers.concat(completedHouseholdMembers)

            positiveCasesAtHousehold = malariaCase.positiveCasesAtHousehold()
            data.passiveCases[caseLocation].passiveCases = data.passiveCases[caseLocation].passiveCases.concat positiveCasesAtHousehold
            data.passiveCases["ALL"].passiveCases = data.passiveCases["ALL"].passiveCases.concat positiveCasesAtHousehold

            _.each malariaCase.positiveCasesIncludingIndex(), (positiveCase) ->
              data.totalPositiveCases[caseLocation].push positiveCase
              data.totalPositiveCases["ALL"].push positiveCase

              if positiveCase.Age?
                age = parseInt(positiveCase.Age)
                if age < 5
                  data.ages[caseLocation].underFive.push positiveCase
                  data.ages["ALL"].underFive.push positiveCase
                else if age < 15
                  data.ages[caseLocation].fiveToFifteen.push positiveCase
                  data.ages["ALL"].fiveToFifteen.push positiveCase
                else if age < 25
                  data.ages[caseLocation].fifteenToTwentyFive.push positiveCase
                  data.ages["ALL"].fifteenToTwentyFive.push positiveCase
                else if age >= 25
                  data.ages[caseLocation].overTwentyFive.push positiveCase
                  data.ages["ALL"].overTwentyFive.push positiveCase
              else
                data.ages[caseLocation].unknown.push positiveCase unless positiveCase.age
                data.ages["ALL"].unknown.push positiveCase unless positiveCase.age
    
              if positiveCase.Sex is "Male"
                data.gender[caseLocation].male.push positiveCase
                data.gender["ALL"].male.push positiveCase
              else if positiveCase.Sex is "Female"
                data.gender[caseLocation].female.push positiveCase
                data.gender["ALL"].female.push positiveCase
              else
                data.gender[caseLocation].unknown.push positiveCase
                data.gender["ALL"].unknown.push positiveCase

              if (positiveCase.SleptunderLLINlastnight is "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight is "Yes")
                data.netsAndIRS[caseLocation].sleptUnderNet.push positiveCase
                data.netsAndIRS["ALL"].sleptUnderNet.push positiveCase

              if (positiveCase.LastdateofIRS and positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/))
                # if date of spraying is less than X months
                if (new moment).subtract('months',Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))
                  data.netsAndIRS[caseLocation].recentIRS.push positiveCase
                  data.netsAndIRS["ALL"].recentIRS.push positiveCase
                
              if (positiveCase.TravelledOvernightinpastmonth?.match(/yes/i) || positiveCase.OvernightTravelinpastmonth?.match(/yes/i))
                data.travel[caseLocation].travelReported.push positiveCase
                data.travel["ALL"].travelReported.push positiveCase

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

  @casesWithoutCompleteHouseholdVisit: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract('days',9).format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract('days',2).format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        options.success(cases.followups["ALL"]?.casesWithoutCompleteHouseholdVisit)

  @unknownDistricts: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract('days',14).format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract('days',7).format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        options.success(cases.followups["UNKNOWN"]?.casesWithoutCompleteHouseholdVisit)
