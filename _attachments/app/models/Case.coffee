class Case
  constructor: (options) ->
    @caseID = options?.caseID
    @loadFromResultDocs(options.results) if options?.results

  loadFromResultDocs: (resultDocs) ->
    @caseResults = resultDocs
    @questions = []
    this["Household Members"] = []
    this["Neighbor Households"] = []

    userRequiresDeidentification = (User.currentUser?.hasRole("reports") or User.currentUser is null) and not User.currentUser?.hasRole("admin")

    _.each resultDocs, (resultDoc) =>
      resultDoc = resultDoc.toJSON() if resultDoc.toJSON?

      if userRequiresDeidentification
        _.each resultDoc, (value,key) ->
          resultDoc[key] = b64_sha1(value) if value? and _.contains(Coconut.identifyingAttributes, key)

      if resultDoc.question
        @caseID ?= resultDoc["MalariaCaseID"]
        throw "Inconsistent Case ID" if @caseID isnt resultDoc["MalariaCaseID"]
        @questions.push resultDoc.question
        if resultDoc.question is "Household Members"
          this["Household Members"].push resultDoc
        else if resultDoc.question is "Household" and resultDoc.Reasonforvisitinghousehold is "Index Case Neighbors"
          this["Neighbor Households"].push resultDoc
        else
          if resultDoc.question is "Facility"
            dateOfPositiveResults = resultDoc.DateofPositiveResults
            if dateOfPositiveResults?
              dayMonthYearMatch = dateOfPositiveResults.match(/^(\d\d).(\d\d).(20\d\d)/)
              if dayMonthYearMatch
                [day,month,year] = dayMonthYearMatch[1..]
                if day > 31 or month > 12
                  console.error "Invalid DateOfPositiveResults: #{this}"
                else
                  resultDoc.DateofPositiveResults = "#{year}-#{month}-#{day}"

          if this[resultDoc.question]?
            # Duplicate
            if this[resultDoc.question].complete is "true" and (resultDoc.complete isnt "true")
              console.log "Using the result marked as complete"
              return #  Use the version already loaded which is marked as complete 
            else if this[resultDoc.question].complete and resultDoc.complete
              console.warn "Duplicate complete entries for case: #{@caseID}"
          this[resultDoc.question] = resultDoc
      else
        @caseID ?= resultDoc["caseid"]
        if @caseID isnt resultDoc["caseid"]
          console.log resultDoc
          console.log resultDocs
          throw "Inconsistent Case ID. Working on #{@caseID} but current doc has #{resultDoc["caseid"]}: #{JSON.stringify resultDoc}"
        @questions.push "USSD Notification"
        this["USSD Notification"] = resultDoc

  fetch: (options) ->

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
      key: @caseID
      include_docs: true
      success: (result) =>
        @loadFromResultDocs(_.pluck(result.rows, "doc"))
        options?.success()
      error: =>
        options?.error()

  toJSON: =>
    returnVal = {}
    _.each @questions, (question) =>
      returnVal[question] = this[question]
    return returnVal

  deIdentify: (result) ->
    
  flatten: (questions = @questions) ->
    returnVal = {}
    _.each questions, (question) =>
      type = question
      _.each this[question], (value, field) ->
        if _.isObject value
          _.each value, (arrayValue, arrayField) ->
            returnVal["#{question}-#{field}: #{arrayField}"] = arrayValue
        else
          returnVal["#{question}:#{field}"] = value
    returnVal

  LastModifiedAt: ->
    _.chain(@toJSON())
    .map (question) ->
      question.lastModifiedAt
    .max (lastModifiedAt) ->
      lastModifiedAt?.replace(/[- :]/g,"")
    .value()

  Questions: ->
    _.keys(@toJSON()).join(", ")

  MalariaCaseID: ->
    @caseID

  user: ->
    userId = @.Household?.user || @.Facility?.user || @["Case Notification"]?.user
  
  facility: ->
    @["Case Notification"]?.FacilityName or @["USSD Notification"]?.hf

  isShehiaValid: =>
    if @validShehia() then true else false

  validShehia: ->
    # Try and find a shehia is in our database
    if @.Household?.Shehia and GeoHierarchy.validShehia(@.Household.Shehia)
      return @.Household?.Shehia
    else if @.Facility?.Shehia and GeoHierarchy.validShehia(@.Facility.Shehia)
      return @.Facility?.Shehia
    else if @["Case Notification"]?.Shehia and GeoHierarchy.validShehia(@["Case Notification"]?.Shehia)
      return @["Case Notification"]?.Shehia
    else if @["USSD Notification"]?.shehia and GeoHierarchy.validShehia(@["USSD Notification"]?.shehia)
      return @["USSD Notification"]?.shehia

    return null

  shehia: ->
    returnVal = @validShehia()
    return returnVal if returnVal?

    console.warn "No valid shehia found for case: #{@MalariaCaseID()} result will be either null or unknown. Case details:"
    console.warn @

    # If no valid shehia is found, then return whatever was entered (or null)
    @.Household?.Shehia || @.Facility?.Shehia || @["Case Notification"]?.shehia || @["USSD Notification"]?.shehia

  village: ->
    @["Facility"]?.Village

  # Want best guess for the district - try and get a valid shehia, if not use district for reporting facility
  district: ->
    shehia = @validShehia()
    if shehia?
      
      findOneShehia = GeoHierarchy.findOneShehia(shehia)
      if findOneShehia
        return findOneShehia.DISTRICT
      else
        shehias = GeoHierarchy.findShehia(shehia)
        district = GeoHierarchy.swahiliDistrictName @["USSD Notification"]?.facility_district
        shehiaWithSameFacilityDistrict = _(shehias).findWhere {DISTRICT: district}
        if shehiaWithSameFacilityDistrict
          return shehiaWithSameFacilityDistrict.DISTRICT

    else
      console.warn "#{@MalariaCaseID()}: No valid shehia found, using district of reporting health facility (which may not be where the patient lives). Data from USSD Notification:"
      console.warn @["USSD Notification"]

      district = GeoHierarchy.swahiliDistrictName @["USSD Notification"]?.facility_district
      if _(GeoHierarchy.allDistricts()).include district
        return district
      else
        console.warn "#{@MalariaCaseID()}: The reported district (#{district}) used for the reporting facility is not a valid district. Looking up the district for the health facility name."
        district = GeoHierarchy.swahiliDistrictName(FacilityHierarchy.getDistrict @["USSD Notification"]?.hf)
        if _(GeoHierarchy.allDistricts()).include district
          return district
        else
          console.warn "#{@MalariaCaseID()}: The health facility name (#{@["USSD Notification"]?.hf}) is not valid. Giving up and returning UNKNOWN."
          return "UNKNOWN"

  highRiskShehia: (date) =>
    date = moment().startOf('year').format("YYYY-MM") unless date
    _(Coconut.shehias_high_risk[date]).contains @shehia()

  locationBy: (geographicLevel) =>
    return @district() if geographicLevel.match(/district/i)
    return @validShehia() if geographicLevel.match(/shehia/i)

  possibleQuestions: ->
    ["Case Notification", "Facility","Household","Household Members"]
  
  questionStatus: =>
    result = {}
    _.each @possibleQuestions(), (question) =>
      if question is "Household Members"
        result["Household Members"] = true
        _.each @["Household Members"]?, (member) ->
          result["Household Members"] = false if member.complete is "false"
      else
        result[question] = (@[question]?.complete is "true")
    return result
      
  complete: =>
    @questionStatus()["Household Members"] is true

  hasCompleteFacility: =>
    @.Facility?.complete is "true"

  notCompleteFacilityAfter24Hours: =>
    @moreThan24HoursSinceFacilityNotifed() and not @hasCompleteFacility()


  notFollowedUpAfter48Hours: =>
    @moreThan48HoursSinceFacilityNotifed() and not @followedUp()

  followedUpWithin48Hours: =>
    not @notFollowedUpAfter48Hours()

  # Includes any kind of travel including only within Zanzibar
  indexCaseHasTravelHistory: =>
    @.Facility?.TravelledOvernightinpastmonth?.match(/Yes/)?

  indexCaseHasNoTravelHistory: =>
    not @indexCaseHasTravelHistory()

  completeHouseholdVisit: =>
    @.Household?.complete is "true" or @.Facility?.Hassomeonefromthesamehouseholdrecentlytestedpositiveatahealthfacility is "Yes"

  followedUp: =>
    @completeHouseholdVisit()

  location: (type) ->
    # Not sure how this works, since we are using the facility name with a database of shehias
    #WardHierarchy[type](@toJSON()["Case Notification"]?["FacilityName"])
    GeoHierarchy.findOneShehia(@toJSON()["Case Notification"]?["FacilityName"])?[type.toUpperCase()]

  withinLocation: (location) ->
    return @location(location.type) is location.name

  completeIndexCaseHouseholdMembers: =>
    return [] unless @["Household"]?
    _(@["Household Members"]).filter (householdMember) =>
      householdMember.HeadofHouseholdName is @["Household"].HeadofHouseholdName and householdMember.complete is "true"

  hasCompleteIndexCaseHouseholdMembers: =>
    @completeIndexCaseHouseholdMembers().length > 0

  positiveCasesAtIndexHousehold: ->
    _(@completeIndexCaseHouseholdMembers()).filter (householdMember) ->
      householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"

  numberPositiveCasesAtIndexHousehold: =>
    @positiveCasesAtIndexHousehold().length

  hasAdditionalPositiveCasesAtIndexHousehold: =>
    @numberPositiveCasesAtIndexHousehold() > 0


  completeNeighborHouseholds: =>
    _(@["Neighbor Households"]).filter (household) =>
      household.complete is "true"

  completeNeighborHouseholdMembers: =>
    return [] unless @["Household"]?
    _(@["Household Members"]).filter (householdMember) =>
      householdMember.HeadofHouseholdName isnt @["Household"].HeadofHouseholdName and householdMember.complete is "true"
  
  hasCompleteNeighborHouseholdMembers: =>
    @completeIndexCaseHouseholdMembers().length > 0

  positiveCasesAtNeighborHouseholds: ->
    _(@completeNeighborHouseholdMembers()).filter (householdMember) ->
      householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"

  positiveCasesAtIndexHouseholdAndNeighborHouseholds: ->
    _(@["Household Members"]).filter (householdMember) =>
      householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"

  positiveCasesAtIndexHouseholdAndNeighborHouseholdsUnder5: =>
    _(@positiveCasesAtIndexHouseholdAndNeighborHouseholds()).filter (householdMemberOrNeighbor) =>
      @ageInYears() < 5
        
  positiveCasesAtIndexHouseholdAndNeighborHouseholdsOver5: =>
    _(@positiveCasesAtIndexHouseholdAndNeighborHouseholds()).filter (householdMemberOrNeighbor) =>
      @ageInYears >= 5


  numberPositiveCasesAtIndexHouseholdAndNeighborHouseholds: ->
    @positiveCasesAtIndexHouseholdAndNeighborHouseholds().length

  numberHouseholdOrNeighborMembers: ->
    @["Household Members"].length

  numberHouseholdOrNeighborMembersTested: ->
    _(@["Household Members"]).filter (householdMember) =>
      householdMember.MalariaTestResult is "NPF"
    .length

  positiveCasesIncludingIndex: =>
    if @["Facility"]
      @positiveCasesAtIndexHouseholdAndNeighborHouseholds().concat(_.extend @["Facility"], @["Household"])
    else if @["USSD Notification"]
      @positiveCasesAtIndexHouseholdAndNeighborHouseholds().concat(_.extend @["USSD Notification"], @["Household"], {MalariaCaseID: @MalariaCaseID()})

  numberPositiveCasesIncludingIndex: =>
    @positiveCasesIncludingIndex.length
      
  indexCasePatientName: ->
    if @["Facility"]?.complete is "true"
      return "#{@["Facility"].FirstName} #{@["Facility"].LastName}"
    if @["USSD Notification"]?
      return @["USSD Notification"]?.name
    if @["Case Notification"]?
      return @["Case Notification"]?.Name

  indexCaseDiagnosisDate: ->
    if @["Facility"]?.DateofPositiveResults?
      date = @["Facility"].DateofPositiveResults
      if date.match(/^20\d\d/)
        return moment(@["Facility"].DateofPositiveResults).format("YYYY-MM-DD")
      else
        return moment(@["Facility"].DateofPositiveResults, "DD-MM-YYYY").format("YYYY-MM-DD")
    else if @["USSD Notification"]?
      return moment(@["USSD Notification"].date).format("YYYY-MM-DD")

    else if @["Case Notification"]?
      return moment(@["Case Notification"].createdAt).format("YYYY-MM-DD")

  householdMembersDiagnosisDates: =>
    @householdMembersDiagnosisDate()

  householdMembersDiagnosisDate: =>
    returnVal = []
    _.each @["Household Members"]?, (member) ->
      returnVal.push member.lastModifiedAt if member.MalariaTestResult is "PF" or member.MalariaTestResult is "Mixed"

  ageInYears: =>
    return null unless @Facility
    if @Facility["Age in Months Or Years"]? and @Facility["Age in Months Or Years"] is "Months"
      @Facility["Age"] / 12.0
    else
      @Facility["Age"]

  isUnder5: =>
    @ageInYears < 5
  
  resultsAsArray: =>
    _.chain @possibleQuestions()
    .map (question) =>
      @[question]
    .flatten()
    .compact()
    .value()

  fetchResults: (options) =>
    results = _.map @resultsAsArray(), (result) =>
      returnVal = new Result()
      returnVal.id = result._id
      returnVal

    count = 0
    _.each results, (result) ->
      result.fetch
        success: ->
          count += 1
          options.success(results) if count >= results.length
    return results


  updateCaseID: (newCaseID) ->
    @fetchResults
      success: (results) ->
        _.each results, (result) ->
          throw "No MalariaCaseID" unless result.attributes.MalariaCaseID?
          result.save
            MalariaCaseID: newCaseID

  issuesRequiringCleaning: () ->
    # Case has multiple USSD notifications
    resultCount = {}
    questionTypes = "USSD Notification, Case Notification, Facility, Household, Household Members".split(/, /)
    _.each questionTypes, (questionType) ->
      resultCount[questionType] = 0

    _.each @caseResults, (result) ->
      resultCount["USSD Notification"]++ if result.caseid?
      resultCount[result.question]++ if result.question?

    issues = []
    _.each questionTypes[0..3], (questionType) ->
      issues.push "#{resultCount[questionType]} #{questionType}s" if resultCount[questionType] > 1
    issues.push "Not followed up" unless @followedUp()
    issues.push "Orphaned result" if @caseResults.length is 1
    issues.push "Missing case notification" unless @["Case Notification"]? or @["Case Notification"]?.length is 0

    return issues
  

  allResultsByQuestion: ->
    returnVal = {}
    _.each "USSD Notification, Case Notification, Facility, Household".split(/, /), (question) ->
      returnVal[question] = []

    _.each  @caseResults, (result) ->
      if result["question"]?
        returnVal[result["question"]].push result
      else if result.hf?
        returnVal["USSD Notification"].push result

    return returnVal

  redundantResults: ->
    redundantResults = []
    _.each @allResultsByQuestion, (results, question) ->
      console.log _.sort(results, "createdAt")

  daysBetweenPositiveResultAndNotification: =>

    dateOfPositiveResults = if @["Facility"]?.DateofPositiveResults?
      date = @["Facility"].DateofPositiveResults
      if date.match(/^20\d\d/)
        moment(@["Facility"].DateofPositiveResults).format("YYYY-MM-DD")
      else
        moment(@["Facility"].DateofPositiveResults, "DD-MM-YYYY").format("YYYY-MM-DD")

    notificationDate = if @["USSD Notification"]?
      @["USSD Notification"].date

    if dateOfPositiveResults? and notificationDate?
      Math.abs(moment(dateOfPositiveResults).diff(notificationDate, 'days'))
    

  timeFacilityNotified: =>
    if @["USSD Notification"]?
      @["USSD Notification"].date
    else
      null

  timeSinceFacilityNotified: =>
    timeFacilityNotified = @timeFacilityNotified()
    if timeFacilityNotified?
      moment().diff(timeFacilityNotified)
    else
      null

  hoursSinceFacilityNotified: =>
    timeSinceFacilityNotified = @timeSinceFacilityNotified()
    if timeSinceFacilityNotified?
      moment.duration(timeSinceFacilityNotified).asHours()
    else
      null

   moreThan24HoursSinceFacilityNotifed: =>
     @hoursSinceFacilityNotified() > 24

   moreThan48HoursSinceFacilityNotifed: =>
     @hoursSinceFacilityNotified() > 48

  timeFromSMSToCaseNotification: =>
    if @["Case Notification"]? and @["USSD Notification"]?
      return moment(@["Case Notification"]?.createdAt).diff(@["USSD Notification"]?.date)

  # Note the replace call to handle a bug that created lastModified entries with timezones
  timeFromCaseNotificationToCompleteFacility: =>
    if @["Facility"]?.complete is "true" and @["Case Notification"]?
      return moment(@["Facility"].lastModifiedAt.replace(/\+0\d:00/,"")).diff(@["Case Notification"]?.createdAt)

  daysFromCaseNotificationToCompleteFacility: =>
    if @["Facility"]?.complete is "true" and @["Case Notification"]?
      moment.duration(@timeFromCaseNotificationToCompleteFacility()).asDays()

  timeFromFacilityToCompleteHousehold: =>
    if @["Household"]?.complete is "true" and @["Facility"]?
      return moment(@["Household"].lastModifiedAt.replace(/\+0\d:00/,"")).diff(@["Facility"]?.lastModifiedAt)

  timeFromSMSToCompleteHousehold: =>
    if @["Household"]?.complete is "true" and @["USSD Notification"]?
      return moment(@["Household"].lastModifiedAt.replace(/\+0\d:00/,"")).diff(@["USSD Notification"]?.date)

  daysFromSMSToCompleteHousehold: =>
    if @["Household"]?.complete is "true" and @["USSD Notification"]?
      moment.duration(@timeFromSMSToCompleteHousehold()).asDays()

  spreadsheetRow: (question) =>
    console.error "Must call loadSpreadsheetHeader at least once before calling spreadsheetRow" unless Coconut.spreadsheetHeader?

    spreadsheetRowObjectForResult = (fields,result) ->
      if result?
        _(fields).map (field) =>
          if result[field]?
            if _.contains(Coconut.identifyingAttributes, field)
              return b64_sha1(result[field])
            else
              return result[field]
          else
            return ""
      else
        return null

    if question is "Household Members"
      _(@[question]).map (householdMemberResult) ->
        spreadsheetRowObjectForResult(Coconut.spreadsheetHeader[question], householdMemberResult)
    else
      spreadsheetRowObjectForResult(Coconut.spreadsheetHeader[question], @[question])

  spreadsheetRowString: (question) =>

    if question is "Household Members"
      _(@spreadsheetRow(question)).map (householdMembersRows) ->
        result = _(householdMembersRows).map (data) ->
          "\"#{data}\""
        .join(",")
        result += "--EOR--" if result isnt ""
      .join("")
    else
      result = _(@spreadsheetRow(question)).map (data) ->
        "\"#{data}\""
      .join(",")
      result += "--EOR--" if result isnt ""


  summaryResult: (property,options) =>
    priorityOrder = options.priorityOrder or [
      "Household"
      "Facility"
      "Case Notification"
      "USSD Notification"
    ]

    if property.match(/:/)
      propertyName = property
      priorityOrder = [property.split(/: */)[0]]

    # If prependQuestion then we only want to search within that question
    priorityOrder = [options.prependQuestion] if options.prependQuestion

    # Make the labels be human readable by looking up the original question text and using that
    labelMappings = {}
    _(priorityOrder).each (question) ->
      return if question is "USSD Notification"
      labelMappings[question] = Coconut.questions.find({id:question}).safeLabelsToLabelsMappings()

    # Looks through the results in the prioritized order for a match
    findPrioritizedProperty = (propertyNames=[property]) =>
      result = null
      _(propertyNames).each (propertyName) =>
        return if result
        _(priorityOrder).each (question) =>
          return if result
          return unless @[question]?
          if @[question][propertyName]?
            result = @[question][propertyName]
            property = labelMappings[question][propertyName] if labelMappings[question] and labelMappings[question][propertyName]

      return result

    result = null

    result = @[property]() if result is null and @[property]
    result = findPrioritizedProperty() if result is null

    if result is null
      result = findPrioritizedProperty(options.otherPropertyNames) if options.otherPropertyNames

    if options.propertyName
      property = options.propertyName
    else
      property = s(property).humanize().titleize().value()

    if options.prependQuestion
      property = "#{options.prependQuestion}: #{property}"

    return {"#{property}": result}

  summary: ->
    _(Case.summaryProperties).map (options, property) =>
      @summaryResult(property, options)

  Case.summaryPropertiesKeys = ->
    _(Case.summaryProperties).map (options, key) ->
      if options.propertyName
        key = options.propertyName
      else
        key = s(key).humanize().titleize().value()

  summaryAsCSVString: =>
    _(@summary()).chain().map (summaryItem) ->
      "\"#{_(summaryItem).values()}\""
    .flatten().value().join(",") + "--EOR--<br/>"

  Case.summaryProperties = {
    
    # TODO Document how the different options work
    # propertyName is used to change the column name at the top of the CSV
    # otherPropertyNames is an array of other values to try and check

    # Case Notification
    MalariaCaseID:
      propertyName: "Malaria Case ID"
    indexCaseDiagnosisDate: {}

    # LostToFollowup: {}

    district:
      propertyName: "District (if no household district uses facility)"
    facility: {}
    facility_district:
      propertyName: "District of Facility"
    shehia: {}
    isShehiaValid: {}
    highRiskShehia: {}
    village:
      propertyName: "Village"

    indexCasePatientName:
      propertyName: "Patient Name"
    ageInYears: {}
    Sex: {}
    isUnder5: {}

    SMSSent:
      propertyName: "SMS Sent to DMSO"
    hasCaseNotification: {}
    numbersSentTo: {}
    source: {}
    source_phone: {}
    type: {}

    hasCompleteFacility: {}
    notCompleteFacilityAfter24Hours: {}
    notFollowedUpAfter48Hours: {}
    followedUpWithin48Hours: {}
    indexCaseHasTravelHistory: {}
    indexCaseHasNoTravelHistory: {}
    completeHouseholdVisit: {}
    numberPositiveCasesAtIndexHousehold: {}
    numberPositiveCasesAtIndexHouseholdAndNeighborHouseholds: {}
    numberHouseholdOrNeighborMembersTested: {}
    numberPositiveCasesIncludingIndex: {}

    CaseIDforotherhouseholdmemberthattestedpositiveatahealthfacility: {}
    CommentRemarks: {}
    ContactMobilepatientrelative: {}
    Hassomeonefromthesamehouseholdrecentlytestedpositiveatahealthfacility: {}
    HeadofHouseholdName: {}
    ParasiteSpecies: {}
    ReferenceinOPDRegister: {}
    ShehaMjumbe: {}
    TravelledOvernightinpastmonth:{}
    IfYESlistALLplacestravelled: {}
      "All Places Traveled to in Past Month"
    TreatmentGiven: {}

    #Household
    CouponNumbers: {}
    FollowupNeighbors: {}
    Haveyougivencouponsfornets: {}
    HeadofHouseholdName: {}
    "HouseholdLocation-accuracy": {}
    "HouseholdLocation-altitude": {}
    "HouseholdLocation-altitudeAccuracy": {}
    "HouseholdLocation-description": {}
    "HouseholdLocation-heading": {}
    "HouseholdLocation-latitude": {}
    "HouseholdLocation-longitude": {}
    "HouseholdLocation-timestamp": {}
    IndexcaseIfpatientisfemale1545yearsofageissheispregant: {}
    IndexcaseOvernightTraveloutsideofZanzibarinthepastyear: {}
    IndexcaseOvernightTravelwithinZanzibar1024daysbeforepositivetestresult: {}
    travelLocationName: {}
    AlllocationsandentrypointsfromovernighttraveloutsideZanzibar07daysbeforepositivetestresult: {}
    AlllocationsandentrypointsfromovernighttraveloutsideZanzibar1521daysbeforepositivetestresult: {}
    AlllocationsandentrypointsfromovernighttraveloutsideZanzibar2242daysbeforepositivetestresult: {}
    AlllocationsandentrypointsfromovernighttraveloutsideZanzibar43365daysbeforepositivetestresult: {}
    AlllocationsandentrypointsfromovernighttraveloutsideZanzibar814daysbeforepositivetestresult: {}
    ListalllocationsofovernighttravelwithinZanzibar1024daysbeforepositivetestresult: {}
    IndexcasePatient: {}
    IndexcasePatientscurrentstatus: {}
    IndexcasePatientstreatmentstatus: {}
    IndexcaseSleptunderLLINlastnight: {}
    LastdateofIRS: {}
    NumberofHouseholdMembersTreatedforMalariaWithinPastWeek: {}
    NumberofHouseholdMemberswithFeverorHistoryofFeverWithinPastWeek: {}
    NumberofLLIN: {}
    NumberofSleepingPlacesbedsmattresses: {}
    Numberofotherhouseholdswithin50stepsofindexcasehousehold: {}
    Reasonforvisitinghousehold: {}
    ShehaMjumbe: {}
    TotalNumberofResidentsintheHousehold: {}

    daysBetweenPositiveResultAndNotification:
      propertyName: "Days Between Positive Result at Facility and Case Notification"
    daysFromCaseNotificationToCompleteFacility: {}
    daysFromSMSToCompleteHousehold:
      propertyName: "Days between SMS Sent to DMSO to Having Complete Household"


    "USSD Notification: Created At":
      otherPropertyNames: ["createdAt"]
    "USSD Notification: Date":
      otherPropertyNames: ["date"]
    "USSD Notification: Last Modified At":
      otherPropertyNames: ["lastModifiedAt"]
    "USSD Notification: User":
      otherPropertyNames: ["user"]
    "Case Notification: Created At":
      otherPropertyNames: ["createdAt"]
    "Case Notification: Last Modified At":
      otherPropertyNames: ["lastModifiedAt"]
    "Case Notification: Saved By":
      otherPropertyNames: ["savedBy"]
    "Facility: Created At":
      otherPropertyNames: ["createdAt"]
    "Facility: Last Modified At":
      otherPropertyNames: ["lastModifiedAt"]
    "Facility: Saved By":
      otherPropertyNames: ["savedBy"]
    "Facility: User":
      otherPropertyNames: ["user"]
    "Household: Created At":
      otherPropertyNames: ["createdAt"]
    "Household: Last Modified At":
      otherPropertyNames: ["lastModifiedAt"]
    "Household: Saved By":
      otherPropertyNames: ["savedBy"]
    "Household: User":
      otherPropertyNames: ["user"]
  }

Case.loadSpreadsheetHeader = (options) ->
  if Coconut.spreadsheetHeader
    options.success()
  else
    $.couch.db(Coconut.config.database_name()).openDoc "spreadsheet_header",
      error: (error) -> console.error JSON.stringify error
      success: (result) ->
        Coconut.spreadsheetHeader = result.fields
        Coconut.spreadsheetHeader.Summary = Case.summaryPropertiesKeys()
        options.success()

Case.updateCaseSpreadsheetDocs = (options) ->

  # defaults used for first run
  caseSpreadsheetData = {_id: "CaseSpreadsheetData" }
  changeSequence = 0

  updateCaseSpreadsheetDocs = (changeSequence, caseSpreadsheetData) ->
    Case.updateCaseSpreadsheetDocsSince
      changeSequence: changeSequence
      error: (error) ->
        console.log "Error updating CaseSpreadsheetData:"
        console.log error
        options.error?()
      success: (numberCasesChanged,lastChangeSequenceProcessed) ->
        console.log "Updated CaseSpreadsheetData"
        caseSpreadsheetData.lastChangeSequenceProcessed = lastChangeSequenceProcessed
        console.log caseSpreadsheetData
        Coconut.database.saveDoc caseSpreadsheetData,
          success: ->
            console.log numberCasesChanged
            if numberCasesChanged > 0
              Case.updateCaseSpreadsheetDocs(options)  #recurse
            else
              options?.success?()

  Coconut.database.openDoc "CaseSpreadsheetData",
    success: (result) ->
      caseSpreadsheetData = result
      changeSequence = result.lastChangeSequenceProcessed
      updateCaseSpreadsheetDocs(changeSequence,caseSpreadsheetData)
    error: (error) ->
      console.log "Couldn't find 'CaseSpreadsheetData' using defaults: changeSequence: #{changeSequence}"
      updateCaseSpreadsheetDocs(changeSequence,caseSpreadsheetData)

Case.updateCaseSpreadsheetDocsSince = (options) ->
  Case.loadSpreadsheetHeader
    success: ->
      $.ajax
        url: "/#{Coconut.config.database_name()}/_changes"
        dataType: "json"
        data:
          since: options.changeSequence
          include_docs: true
          limit: 4000
        error: (error) =>
          console.log "Error downloading changes after #{options.changeSequence}:"
          console.log error
          options.error?(error)
        success: (changes) =>
          changedCases = _(changes.results).chain().map (change) ->
            change.doc.MalariaCaseID if change.doc.MalariaCaseID? and change.doc.question?
          .compact().uniq().value()
          lastChangeSequence = changes.results.pop()?.seq
          Case.updateSpreadsheetForCases
            caseIDs: changedCases
            error: (error) ->
              console.log "Error updating #{changedCases.length} cases, lastChangeSequence: #{lastChangeSequence}"
              console.log error
            success: ->
              console.log "Updated #{changedCases.length} cases, lastChangeSequence: #{lastChangeSequence}"
              options.success(changedCases.length, lastChangeSequence)



Case.updateSpreadsheetForCases = (options) ->
  docsToSave = []
  questions = "USSD Notification,Case Notification,Facility,Household,Household Members".split(",")
  options.success() if options.caseIDs.length is 0

  finished = _.after options.caseIDs.length, ->
    Coconut.database.bulkSave {docs:docsToSave},
      error: (error) -> console.log error
      success: -> options.success()

  _(options.caseIDs).each (caseID) ->
    malariaCase = new Case
      caseID: caseID
    malariaCase.fetch
      error: (error) ->
        console.log error
      success: ->

        docId = "spreadsheet_row_#{caseID}"
        spreadsheet_row_doc = {_id: docId}

        saveRowDoc = (result) ->
          spreadsheet_row_doc = result if result? # if the row already exists use the _rev
          _(questions).each (question) ->
            spreadsheet_row_doc[question] = malariaCase.spreadsheetRowString(question)

          spreadsheet_row_doc["Summary"] = malariaCase.summaryAsCSVString()

          docsToSave.push spreadsheet_row_doc
          finished()

        Coconut.database.openDoc docId,
          success: (result) -> saveRowDoc(result)
          error: -> saveRowDoc()
