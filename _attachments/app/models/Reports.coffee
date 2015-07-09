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

    options.aggregationLevel ||= "DISTRICT"

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
            noFacilityFollowupWithin24Hours: []
            noHouseholdFollowupWithin48Hours: []

          data.passiveCases[aggregationName] =
            indexCases: []
            indexCaseHouseholdMembers: []
            positiveCasesAtIndexHousehold: []
            neighborHouseholds: []
            neighborHouseholdMembers: []
            positiveCasesAtNeighborHouseholds: []
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
            "No":[]
            "Yes within Zanzibar":[]
            "Yes outside Zanzibar":[]
            "Yes within and outside Zanzibar":[]
            "Any travel":[]
            "Not Applicable":[]
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
          if malariaCase.notCompleteFacilityAfter24Hours()
            data.followups[caseLocation].noFacilityFollowupWithin24Hours.push malariaCase
            data.followups["ALL"].noFacilityFollowupWithin24Hours.push malariaCase

          if malariaCase.notFollowedUpAfter48Hours()
            data.followups[caseLocation].noHouseholdFollowupWithin48Hours.push malariaCase
            data.followups["ALL"].noHouseholdFollowupWithin48Hours.push malariaCase


          # This is our current definition of a case that has been followed up
          # TODO - how do we deal with households that are incomplete but that have complete household members
          if malariaCase["Household"]?.complete is "true"
            data.passiveCases[caseLocation].indexCases.push malariaCase
            data.passiveCases["ALL"].indexCases.push malariaCase

            completeIndexCaseHouseholdMembers = malariaCase.completeIndexCaseHouseholdMembers()
            data.passiveCases[caseLocation].indexCaseHouseholdMembers =  data.passiveCases[caseLocation].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers)
            data.passiveCases["ALL"].indexCaseHouseholdMembers =  data.passiveCases["ALL"].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers)

            positiveCasesAtIndexHousehold = malariaCase.positiveCasesAtIndexHousehold()
            data.passiveCases[caseLocation].positiveCasesAtIndexHousehold = data.passiveCases[caseLocation].positiveCasesAtIndexHousehold.concat positiveCasesAtIndexHousehold
            data.passiveCases["ALL"].positiveCasesAtIndexHousehold = data.passiveCases["ALL"].positiveCasesAtIndexHousehold.concat positiveCasesAtIndexHousehold

            completeNeighborHouseholds = malariaCase.completeNeighborHouseholds()
            data.passiveCases[caseLocation].neighborHouseholds =  data.passiveCases[caseLocation].neighborHouseholds.concat(completeNeighborHouseholds)
            data.passiveCases["ALL"].neighborHouseholds =  data.passiveCases["ALL"].neighborHouseholds.concat(completeNeighborHouseholds)

            completeNeighborHouseholdMembers = malariaCase.completeNeighborHouseholdMembers()
            data.passiveCases[caseLocation].neighborHouseholdMembers =  data.passiveCases[caseLocation].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers)
            data.passiveCases["ALL"].neighborHouseholdMembers =  data.passiveCases["ALL"].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers)

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

              if positiveCase.TravelledOvernightinpastmonth?
                data.travel[caseLocation][positiveCase.TravelledOvernightinpastmonth].push positiveCase
                data.travel[caseLocation]["Any travel"].push positiveCase if positiveCase.TravelledOvernightinpastmonth.match(/Yes/)
                data.travel["ALL"][positiveCase.TravelledOvernightinpastmonth].push positiveCase
                data.travel["ALL"]["Any travel"].push positiveCase if positiveCase.TravelledOvernightinpastmonth.match(/Yes/)
              else if positiveCase.OvernightTravelinpastmonth
                data.travel[caseLocation][positiveCase.OvernightTravelinpastmonth].push positiveCase
                data.travel[caseLocation]["Any travel"].push positiveCase if positiveCase.OvernightTravelinpastmonth.match(/Yes/)
                data.travel["ALL"][positiveCase.OvernightTravelinpastmonth].push positiveCase
                data.travel["ALL"]["Any travel"].push positiveCase if positiveCase.OvernightTravelinpastmonth.match(/Yes/)

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

  @userAnalysisTest: ->
    @userAnalysis
      startDate: "2014-10-01"
      endDate: "2014-12-01"
      success: (result) ->
        console.log result

  @userAnalysis: (options) ->
    @userAnalysisForUsers
      # Pass list of usernames
      usernames:  Users.map (user) -> user.username()
      success: options.success
      startDate: options.startDate
      endDate: options.endDate

  @userAnalysisForUsers: (options) ->
    usernames = options.usernames

    Coconut.medianTimeWithHalves = (values) =>
      return [values[0],values[0],values[0]] if values.length is 1

      # Remove negative values, these are probably due to cleaning
      values = _(values).filter (value) -> value >= 0
      values = _(values).compact()

      values.sort  (a,b)=> return a - b
      half = Math.floor values.length/2
      if values.length % 2 #odd
        median = values[half]
        return [median,values[0..half],values[half...]]
      else # even
        median = (values[half-1] + values[half]) / 2.0
        return [median, values[0..half],values[half+1...]]

    Coconut.medianTime = (values)=>
      Coconut.medianTimeWithHalves(values)[0]

    Coconut.medianTimeFormatted = (times) ->
      duration = moment.duration(Coconut.medianTime(times))
      if duration.seconds() is 0 then "-" else duration.humanize()

    Coconut.quintiles = (values) ->
      [median,h1Values,h2Values] = Coconut.medianTimeWithHalves(values)
      console.log h1Values
      [
        Coconut.medianTime(h1Values)
        median
        Coconut.medianTime(h2Values)
      ]

    Coconut.quintile1Time = (values) -> Coconut.quintiles(values)[0]
    Coconut.quintile3Time = (values) -> Coconut.quintiles(values)[2]

    Coconut.quintile1TimeFormatted = (times) ->
      duration = moment.duration(Coconut.quintile1Time(times))
      if duration.seconds() is 0 then "-" else duration.humanize()

    Coconut.quintile3TimeFormatted = (times) ->
      duration = moment.duration(Coconut.quintile3Time(times))
      if duration.seconds() is 0 then "-" else duration.humanize()

    Coconut.averageTime = (times) ->
      sum = 0
      amount = 0
      _(times).each (time) ->
        if time?
          amount += 1
          sum += time

      return 0 if amount is 0
      return sum/amount

    Coconut.averageTimeFormatted = (times) ->
      duration = moment.duration(Coconut.averageTime(times))
      if duration.seconds() is 0
        return "-"
      else
        return duration.humanize()

    # Initialize the dataByUser object
    dataByUser = {}
    _(usernames).each (username) ->
      dataByUser[username] = {
        userId: username
        caseIds: {}
        cases: {}
        casesWithoutCompleteFacilityAfter24Hours: {}
        casesWithoutCompleteHouseholdAfter48Hours: {}
        casesWithCompleteHousehold: {}
        timesFromSMSToCaseNotification: []
        timesFromCaseNotificationToCompleteFacility: []
        timesFromFacilityToCompleteHousehold: []
        timesFromSMSToCompleteHousehold: []
      }

    total = {
      caseIds: {}
      cases: {}
      casesWithoutCompleteFacilityAfter24Hours: {}
      casesWithoutCompleteHouseholdAfter48Hours: {}
      casesWithCompleteHousehold: {}
      timesFromSMSToCaseNotification: []
      timesFromCaseNotificationToCompleteFacility: []
      timesFromFacilityToCompleteHousehold: []
      timesFromSMSToCompleteHousehold: []
    }

    # Get the the caseids for all of the results in the data range with the user id
    $.couch.db(Coconut.config.database_name()).view "zanzibar-server/resultsByDateWithUserAndCaseId",
      startkey: options.startDate
      endkey: options.endDate
      include_docs: false
      success: (results) ->
        _(results.rows).each (result) ->
          caseId = result.value[1]
          user = result.value[0]
          dataByUser[user].caseIds[caseId] = true
          dataByUser[user].cases[caseId] = {}
          total.caseIds[caseId] = true
          total.cases[caseId] = {}

        _(dataByUser).each (userData,user) ->
          if _(dataByUser[user].cases).size() is 0
            delete dataByUser[user]

        successWhenDone = _.after _(dataByUser).size(), ->
          options.success
            dataByUser: dataByUser
            total: total

        _(dataByUser).each (userData,user) ->
          # Get the time differences within each case
          caseIds = _(userData.cases).map (foo, caseId) -> caseId

          $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
            keys: caseIds
            include_docs: true
            error: (error) ->
              console.error "Error finding cases: " + JSON.stringify error
            success: (result) ->
              caseId = null
              caseResults = []
              # Collect all of the results for each caseid, then creeate the case and  process it
              _.each result.rows, (row) ->
                if caseId? and caseId isnt row.key
                  malariaCase = new Case
                    caseID: caseId
                    results: caseResults
                  caseResults = []

                  userData.cases[caseId] = malariaCase
                  total.cases[caseId] = malariaCase

                  if malariaCase.notCompleteFacilityAfter24Hours()
                    userData.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase
                    total.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase

                  if malariaCase.notFollowedUpAfter48Hours()
                    userData.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase
                    total.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase

                  if malariaCase.followedUp()
                    userData.casesWithCompleteHousehold[caseId] = malariaCase
                    total.casesWithCompleteHousehold[caseId] = malariaCase

                  _([
                    "SMSToCaseNotification"
                    "CaseNotificationToCompleteFacility"
                    "FacilityToCompleteHousehold"
                    "SMSToCompleteHousehold"
                  ]).each (property) ->

                    userData["timesFrom#{property}"].push malariaCase["timeFrom#{property}"]()
                    total["timesFrom#{property}"].push malariaCase["timeFrom#{property}"]()

                caseResults.push row.doc
                caseId = row.key

              _(userData.cases).each (results,caseId) ->
                _([
                  "SMSToCaseNotification"
                  "CaseNotificationToCompleteFacility"
                  "FacilityToCompleteHousehold"
                  "SMSToCompleteHousehold"
                ]).each (property) ->
                  _(["quintile1","median","quintile3"]).each (dataPoint) ->
                    userData["#{dataPoint}TimeFrom#{property}"] = Coconut["#{dataPoint}TimeFormatted"](userData["timesFrom#{property}"])
                    userData["#{dataPoint}TimeFrom#{property}Seconds"] = Coconut["#{dataPoint}Time"](userData["timesFrom#{property}"])

                    total["#{dataPoint}TimeFrom#{property}"] = Coconut["#{dataPoint}TimeFormatted"](total["timesFrom#{property}"])
                    total["#{dataPoint}TimeFrom#{property}Seconds"] = Coconut["#{dataPoint}Time"](total["timesFrom#{property}"])


              successWhenDone()


  @aggregateWeeklyReports = (options) ->
    startDate = moment(options.startDate)
    startYear = startDate.format("YYYY")
    startWeek =startDate.format("ww")
    endDate = moment(options.endDate).endOf("day")
    endYear = endDate.format("YYYY")
    endWeek = endDate.format("ww")
    aggregationArea = options.aggregationArea
    aggregationPeriod = options.aggregationPeriod
    facilityType = options.facilityType or "All"
    $.couch.db(Coconut.config.database_name()).view "zanzibar-server/weeklyDataBySubmitDate",
      startkey: [startYear,startWeek]
      endkey: [endYear,endWeek]
      include_docs: true
      success: (results) =>
        cumulativeFields = {
          "All OPD < 5" : 0
          "Mal POS < 5" : 0
          "Mal NEG < 5" : 0
          "All OPD >= 5" : 0
          "Mal POS >= 5" : 0
          "Mal NEG >= 5" : 0
        }

        aggregatedData = {}

        _(results.rows).each (row) =>
          weeklyReport = row.doc
          date = moment().year(weeklyReport.Year).week(weeklyReport.Week)
          period = Reports.getAggregationPeriodDate(aggregationPeriod,date)

          if facilityType isnt "All"
            return if FacilityHierarchy.facilityType(weeklyReport.Facility) isnt facilityType.toUpperCase()

          area = weeklyReport[aggregationArea]
          if aggregationArea is "District"
            area = GeoHierarchy.swahiliDistrictName(area)

          aggregatedData[period] = {} unless aggregatedData[period]
          aggregatedData[period][area] = _(cumulativeFields).clone() unless aggregatedData[period][area]
          _(_(cumulativeFields).keys()).each (field) ->
            aggregatedData[period][area][field] += parseInt(weeklyReport[field])


          aggregatedData[period][area]["Reports submitted for period"] = 0 unless aggregatedData[period][area]["Reports submitted for period"]
          aggregatedData[period][area]["Reports submitted for period"] += 1

          endDayForReportPeriod = moment("#{weeklyReport.Year} #{weeklyReport.Week}","YYYY WW").endOf("week")
          numberOfDaysSinceEndOfPeriodReportSubmitted = moment(weeklyReport["Submit Date"]).diff(endDayForReportPeriod,"days")

          aggregatedData[period][area]["Report submitted within 1 day"] = 0 unless aggregatedData[period][area]["Report submitted within 1 day"]
          aggregatedData[period][area]["Report submitted 1-3 days"] = 0 unless aggregatedData[period][area]["Report submitted 1-3 days"]
          aggregatedData[period][area]["Report submitted 3-5 days"] = 0 unless aggregatedData[period][area]["Report submitted 3-5 days"]
          aggregatedData[period][area]["Report submitted 5+ days"] = 0 unless aggregatedData[period][area]["Report submitted 5+ days"]

          if numberOfDaysSinceEndOfPeriodReportSubmitted <= 1
            aggregatedData[period][area]["Report submitted within 1 day"] +=1
          else if numberOfDaysSinceEndOfPeriodReportSubmitted > 1 and numberOfDaysSinceEndOfPeriodReportSubmitted <= 3
            aggregatedData[period][area]["Report submitted 1-3 days"] +=1
          else if numberOfDaysSinceEndOfPeriodReportSubmitted > 3 and numberOfDaysSinceEndOfPeriodReportSubmitted <= 5
            aggregatedData[period][area]["Report submitted 3-5 days"] +=1
          else if numberOfDaysSinceEndOfPeriodReportSubmitted > 5
            aggregatedData[period][area]["Report submitted 5+ days"] +=1


        options.success {
          fields: _(cumulativeFields).keys()
          data: aggregatedData
        }

  @aggregatePositiveFacilityCases = (options) ->
    aggregationArea = options.aggregationArea
    aggregationPeriod = options.aggregationPeriod

    $.couch.db(Coconut.config.database_name()).view "zanzibar-server/positiveFacilityCasesByDate",
      startkey: options.startDate
      endkey: options.endDate
      include_docs: false
      success: (result) ->
        aggregatedData = {}

        _.each result.rows, (row) ->
          date = moment(row.key)

          period = switch aggregationPeriod
            when "Week" then date.format("YYYY-ww")
            when "Month" then date.format("YYYY-MM")
            when "Quarter" then "#{date.format("YYYY")}q#{Math.floor((date.month() + 3) / 3)}"
            when "Year" then date.format("YYYY")

          caseId = row.value[0]
          facility = row.value[1]
          area = switch aggregationArea
            when "Zone" then FacilityHierarchy.getZone(facility)
            when "District" then FacilityHierarchy.getDistrict(facility)
            when "Facility" then facility
          area = "Unknown" if area is null

          aggregatedData[period] = {} unless aggregatedData[period]
          aggregatedData[period][area] = [] unless aggregatedData[period][area]
          aggregatedData[period][area].push caseId

        options.success aggregatedData

  @aggregateWeeklyReportsAndFacilityCases = (options) =>
    options.localSuccess = options.success
    #Note that the order of the commands below is confusing
    #
    # This is what is called after doing the aggregateWeeklyReports
    options.success = (data) =>
      # This is what is called after doing the aggregatePositiveFacilityCases
      options.success = (facilityCaseData) ->
        data.fields.push "Facility Followed-Up Positive Cases"
        _(facilityCaseData).each (areas, period) ->
          _(areas).each (positiveFacilityCases, area) ->
            data.data[period] = {} unless data.data[period]
            data.data[period][area] = {} unless data.data[period][area]
            data.data[period][area]["Facility Followed-Up Positive Cases"] = positiveFacilityCases
        options.localSuccess data
        
      @aggregatePositiveFacilityCases options
    @aggregateWeeklyReports options

  @aggregateWeeklyReportsAndFacilityTimeliness = (options) =>
    options.localSuccess = options.success
    #Note that the order of the commands below is confusing
    #
    # This is what is called after doing the aggregateWeeklyReports
    options.success = (data) =>
      # This is what is called after doing the aggregateTimelinessForCases
      options.success = (facilityCaseData) ->
        _(facilityCaseData).each (areaData, period) ->
          _(areaData).each (caseData, area) ->
            data.data[period] = {} unless data.data[period]
            data.data[period][area] = {} unless data.data[period][area]

            _([
              "daysBetweenPositiveResultAndNotification"
              "daysFromCaseNotificationToCompleteFacility"
              "daysFromSMSToCompleteHousehold"
              "numberHouseholdOrNeighborMembers"
              "numberHouseholdOrNeighborMembersTested"
              "numberPositiveCasesAtIndexHouseholdAndNeighborHouseholds"
              "hasCompleteFacility"
              "casesNotified"
              "householdFollowedUp"
              "followedUpWithin48Hours"
            ]).each (property) ->
              data.data[period][area][property] = caseData[property]

        options.localSuccess data
        
      @aggregateTimelinessForCases options
    @aggregateWeeklyReports options

  

  @aggregateTimelinessForCases = (options) ->
    aggregationArea = options.aggregationArea
    aggregationPeriod = options.aggregationPeriod
    facilityType = options.facilityType

    $.couch.db(Coconut.config.database_name()).view "zanzibar-server/positiveFacilityCasesByDate",
      startkey: options.startDate
      endkey: options.endDate
      include_docs: false
      success: (result) ->
        aggregatedData = {}

        _.each result.rows, (row) ->
          date = moment(row.key)

          period = Reports.getAggregationPeriodDate(aggregationPeriod,date)

          caseId = row.value[0]
          if caseId is null
            console.log "Case missing case ID: #{row.id}, skipping"
            return
          facility = row.value[1]

          if facilityType isnt "All"
            return if FacilityHierarchy.facilityType(facility) isnt facilityType.toUpperCase()

          area = switch aggregationArea
            when "Zone" then FacilityHierarchy.getZone(facility)
            when "District" then FacilityHierarchy.getDistrict(facility)
            when "Facility" then facility
          area = "Unknown" if area is null

          aggregatedData[period] = {} unless aggregatedData[period]
          aggregatedData[period][area] = {} unless aggregatedData[period][area]
          aggregatedData[period][area]["cases"] = [] unless aggregatedData[period][area]["cases"]
          aggregatedData[period][area]["cases"].push caseId

        caseIdsToFetch = _.chain(aggregatedData).map (areaData,period) ->
          _(areaData).map (caseData,area) ->
            caseData.cases
        .flatten()
        .uniq()
        .value()

        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
          keys: caseIdsToFetch
          include_docs: true
          error: => options?.error()
          success: (result) =>
            cases = {}
            _.chain(result.rows).groupBy (row) =>
              row.key
            .each (resultsByCaseID) =>
              cases[resultsByCaseID[0].key] = new Case
                results: _.pluck resultsByCaseID, "doc"

            _(aggregatedData).each (areaData,period) ->
              _(areaData).each (caseData,area) ->
                _(caseData.cases).each (caseId) ->
                  _([
                    "daysBetweenPositiveResultAndNotification"
                    "daysFromCaseNotificationToCompleteFacility"
                    "daysFromSMSToCompleteHousehold"
                  ]).each (property) ->
                    aggregatedData[period][area][property] = [] unless aggregatedData[period][area][property]
                    aggregatedData[period][area][property].push cases[caseId][property]()

                  _([
                    "numberHouseholdOrNeighborMembers"
                    "numberHouseholdOrNeighborMembersTested"
                    "numberPositiveCasesAtIndexHouseholdAndNeighborHouseholds"
                  ]).each (property) ->
                    aggregatedData[period][area][property] = 0 unless aggregatedData[period][area][property]
                    aggregatedData[period][area][property]+= cases[caseId][property]()

                  aggregatedData[period][area]["householdFollowedUp"] = 0 unless aggregatedData[period][area]["householdFollowedUp"]
                  aggregatedData[period][area]["householdFollowedUp"]+= 1 if cases[caseId].followedUp()

                  _(["hasCompleteFacility","followedUpWithin48Hours"]).each (property) ->
                    aggregatedData[period][area][property] = [] unless aggregatedData[period][area][property]
                    aggregatedData[period][area][property].push caseId if cases[caseId][property]()

                  aggregatedData[period][area]["casesNotified"] = [] unless aggregatedData[period][area]["casesNotified"]
                  aggregatedData[period][area]["casesNotified"].push caseId

            options.success aggregatedData

Reports.getAggregationPeriodDate = (aggregationPeriod,date) ->
  switch aggregationPeriod
    when "Week" then date.format("YYYY-ww")
    when "Month" then date.format("YYYY-MM")
    when "Quarter" then "#{date.format("YYYY")}q#{Math.floor((date.month() + 3) / 3)}"
    when "Year" then date.format("YYYY")

