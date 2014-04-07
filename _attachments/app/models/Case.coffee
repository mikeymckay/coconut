class Case
  constructor: (options) ->
    @caseID = options?.caseID
    @loadFromResultDocs(options.results) if options?.results

  loadFromResultDocs: (resultDocs) ->
    @caseResults = resultDocs
    @questions = []
    this["Household Members"] = []

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
        else
          #console.error "#{@caseID} already has a result for #{resultDoc.question} - needs cleaning" if this[resultDoc.question]?
          this[resultDoc.question] = resultDoc
      else
        @caseID ?= resultDoc["caseid"]
        if @caseID isnt resultDoc["caseid"]
          console.log resultDoc
          console.log resultDocs
          throw "Inconsistent Case ID. Working on #{@caseID} but current doc has #{resultDoc["caseid"]}"
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

  facility: ->
    console.log @["USSD Notification"]
    @["USSD Notification"]?.hf

  validShehia: ->
    # Try and find a shehia is in our database
    if @.Household?.Shehia and GeoHierarchy.findOneShehia(@.Household.Shehia)
      return @.Household?.Shehia
    else if @.Facility?.Shehia and GeoHierarchy.findOneShehia(@.Facility.Shehia)
      return @.Facility?.Shehia
    else if @["USSD Notification"]?.shehia and GeoHierarchy.findOneShehia(@["USSD Notification"]?.shehia)
      return @["USSD Notification"]?.shehia

    return null

  shehia: ->
    returnVal = @validShehia()
    return returnVal if returnVal?

    console.warn "No valid shehia found for case: #{@MalariaCaseID()} result will be either null or unknown"

    # If no valid shehia is found, then return whatever was entered (or null)
    @.Household?.Shehia || @.Facility?.Shehia || @["USSD Notification"]?.shehia

  user: ->
    userId = @.Household?.user || @.Facility?.user || @["Case Notification"]?.user
  
  # Want best guess for the district - try and get a valid shehia, if not use district for reporting facility
  district: ->
    shehia = @validShehia()
    if shehia?
      return GeoHierarchy.findOneShehia(shehia).DISTRICT
    else
      console.warn "No valid shehia found for case: #{@MalariaCaseID()} using district of reporting health facility (which may not be where the patient lives)"
      return GeoHierarchy.swahiliDistrictName @["USSD Notification"]?.facility_district

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

  followedUp: =>
    @["Household"]?.complete is "true"

  daysFromNotificationToCompletion: =>
    startTime = moment(@["Case Notification"].lastModifiedAt)
    completionTime = null
    _.each @["Household Members"], (member) ->
      completionTime = moment(member.lastModifiedAt) if moment(member.lastModifiedAt) > completionTime
    return completionTime.diff(startTime, "days")

  location: (type) ->
    # Not sure how this works, since we are using the facility name with a database of shehias
    #WardHierarchy[type](@toJSON()["Case Notification"]?["FacilityName"])
    GeoHierarchy.findOneShehia(@toJSON()["Case Notification"]?["FacilityName"])?[type.toUpperCase()]

  withinLocation: (location) ->
    return @location(location.type) is location.name

  hasAdditionalPositiveCasesAtHousehold: ->
    _.any @["Household Members"], (householdMember) ->
      householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"

  positiveCasesAtHousehold: ->
    _.compact(_.map @["Household Members"], (householdMember) ->
      householdMember if householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"
    )

  positiveCasesIncludingIndex: ->
    if @["Facility"]
      @positiveCasesAtHousehold().concat(_.extend @["Facility"], @["Household"])
    else if @["USSD Notification"]
      @positiveCasesAtHousehold().concat(_.extend @["USSD Notification"], @["Household"], {MalariaCaseID: @MalariaCaseID()})
#    else
#      @positiveCasesAtHousehold()
      
  indexCasePatientName: ->
    if @["Facility"]?.complete is "true"
      return "#{@["Facility"].FirstName} #{@["Facility"].LastName}"
    if @["USSD Notification"]?
      return @["USSD Notification"]?.name

  indexCaseDiagnosisDate: ->
    if @["Facility"]?.DateofPositiveResults?
      date = @["Facility"].DateofPositiveResults
      if date.match(/^20\d\d/)
        return moment(@["Facility"].DateofPositiveResults).format("YYYY-MM-DD")
      else
        return moment(@["Facility"].DateofPositiveResults, "DD-MM-YYYY").format("YYYY-MM-DD")
    else if @["USSD Notification"]?
      return moment(@["USSD Notification"].date).format("YYYY-MM-DD")

  householdMembersDiagnosisDate: ->
    returnVal = []
    _.each @["Household Members"]?, (member) ->
      returnVal.push member.lastModifiedAt if member.MalariaTestResult is "PF" or member.MalariaTestResult is "Mixed"
  
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

    
