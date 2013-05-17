class Reports
  constructor: (options = {}) ->
    @startDate = options.startDate || moment(new Date).subtract('days',7).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")
    @cluster = options.cluster || "off"
    @summaryField1 = options.summaryField1
    @alertEmail = options.alertEmail || "false"
    @locationTypes = "region, district, constituan, shehia".split(/, /)
    @mostSpecificLocation = options.mostSpecificLocation || {type:"region", name:"ALL"}

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


  getCases: (options) ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/caseIDsByDate",
      # Note that these seem reversed due to descending order
      startkey: moment(@endDate).endOf("day").format(Coconut.config.get "date_format")
      endkey: @startDate
      descending: true
      include_docs: false
      success: (result) =>

        caseIDs = _.unique(_.pluck result.rows, "value")

        cases = _.map caseIDs, (caseID) =>
          malariaCase = new Case
            caseID: caseID
          malariaCase.fetch
            success: =>
              afterAllCasesDownloaded()
          return malariaCase

        afterAllCasesDownloaded = _.after caseIDs.length, =>
          cases = _.chain(cases)
          .map (malariaCase) =>
            if @mostSpecificLocation.name is "ALL" or malariaCase.withinLocation(mostSpecificLocation)
              return malariaCase
          .compact()
          .value()

          options.success(cases)

  alerts: (callback) ->

    data = {}

    @getCases
      success: (cases) =>
        IRSThresholdInMonths = 6
  
        data.followupsByDistrict = {}
        data.passiveCasesByDistrict = {}
        data.agesByDistrict = {}
        data.netsAndIRSByDistrict = {}
        data.travelByDistrict = {}
        data.totalPositiveCasesByDistrict = {}

        # Setup hashes for each table
        districts = WardHierarchy.allDistricts()
        districts.push("UNKNOWN")
        districts.push("ALL")
        _.each districts, (district) ->
          data.followupsByDistrict[district] =
            meedsCases: []
            casesFollowedUp: []
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
          data.netsAndIRSByDistrict[district] =
            sleptUnderNet: []
            recentIRS: []
          data.travelByDistrict[district] =
            travelReported: []
          data.totalPositiveCasesByDistrict[district] = []

        _.each cases, (malariaCase) ->
          district = malariaCase.district() || "UNKNOWN"
          data.followupsByDistrict[district].meedsCases.push malariaCase if malariaCase["USSD Notification"]?
          data.followupsByDistrict["ALL"].meedsCases.push malariaCase if malariaCase["USSD Notification"]?
          data.followupsByDistrict[district].casesFollowedUp.push malariaCase if malariaCase["Household Members"]?.length > 0
          data.followupsByDistrict["ALL"].casesFollowedUp.push malariaCase if malariaCase["Household Members"]?.length > 0

          data.passiveCasesByDistrict[district].indexCases.push malariaCase if malariaCase["Case Notification"]?
          data.passiveCasesByDistrict["ALL"].indexCases.push malariaCase if malariaCase["Case Notification"]?

          data.passiveCasesByDistrict[district].householdMembers =  data.passiveCasesByDistrict[district].householdMembers.concat(malariaCase["Household Members"]) if malariaCase["Household Members"]?
          data.passiveCasesByDistrict["ALL"].householdMembers =  data.passiveCasesByDistrict["ALL"].householdMembers.concat(malariaCase["Household Members"]) if malariaCase["Household Members"]?

          data.passiveCasesByDistrict[district].passiveCases = data.passiveCasesByDistrict[district].passiveCases.concat malariaCase.positiveCasesAtHousehold()
          data.passiveCasesByDistrict["ALL"].passiveCases = data.passiveCasesByDistrict["ALL"].passiveCases.concat malariaCase.positiveCasesAtHousehold()

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

            if (positiveCase.SleptunderLLINlastnight is "Yes" || positiveCase.IndexcaseSleptunderLLINlastnight is "Yes")
              data.netsAndIRSByDistrict[district].sleptUnderNet.push positiveCase
              data.netsAndIRSByDistrict["ALL"].sleptUnderNet.push positiveCase

            if (positiveCase.LastdateofIRS and positiveCase.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/))
              # if date of spraying is less than X months
              if (new moment).subtract('months',Coconut.IRSThresholdInMonths) < (new moment(positiveCase.LastdateofIRS))
                data.netsAndIRSByDistrict[district].recentIRS.push positiveCase
                data.netsAndIRSByDistrict["ALL"].recentIRS.push positiveCase
              
            if (positiveCase.TravelledOvernightinpastmonth is "Yes" || positiveCase.OvernightTravelinpastmonth is "Yes")
              data.travelByDistrict[district].travelReported.push positiveCase
              data.travelByDistrict["ALL"].travelReported.push positiveCase

        _.each data.followupsByDistrict, (values, district) ->
          data.followupsByDistrict[district].meedsCasesFollowedUp = _.intersection(data.followupsByDistrict[district].meedsCases, data.followupsByDistrict[district].casesFollowedUp)
          data.followupsByDistrict[district].meedsCasesNotFollowedUp = _.difference(data.followupsByDistrict[district].meedsCases, data.followupsByDistrict[district].casesFollowedUp)

        callback(data)
