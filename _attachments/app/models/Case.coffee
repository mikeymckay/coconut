class Case
  constructor: (options) ->
    @caseID = options?.caseID
    @loadFromResultDocs(options.results) if options?.results

  loadFromResultDocs: (resultDocs) ->
    @caseResults = resultDocs
    @questions = []
    this["Household Members"] = []

    _.each resultDocs, (resultDoc) =>
      resultDoc = resultDoc.toJSON() if resultDoc.toJSON?
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
        throw "Inconsistent Case ID. Working on #{@caseID} but current doc has #{resultDoc["caseid"]}" if @caseID isnt resultDoc["caseid"]
        @questions.push "USSD Notification"
        this["USSD Notification"] = resultDoc
    

  fetch: (options) ->

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases"
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
    
  flatten: ->
    returnVal = {}
    _.each @toJSON(), (object,type) ->
      _.each object, (value, field) ->
        if _.isObject value
          _.each value, (arrayValue, arrayField) ->
            returnVal["#{type}-#{field}: #{arrayField}"] = arrayValue
        else
          returnVal["#{type}:#{field}"] = value
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

  daysFromNotificationToCompletion: =>
    startTime = moment(@["Case Notification"].lastModifiedAt)
    completionTime = null
    _.each @["Household Members"], (member) ->
      completionTime = moment(member.lastModifiedAt) if moment(member.lastModifiedAt) > completionTime
    return completionTime.diff(startTime, "days")

  location: (type) ->
    WardHierarchy[type](@toJSON()["Case Notification"]?["FacilityName"])

  withinLocation: (location) ->
    return @location(location.type) is location.name

  hasAdditionalPositiveCasesAtHousehold: ->
    _.any @["Household Members"], (householdMember) ->
      householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed"

  indexCaseDiagnosisDate: ->
    if @["Facility"]?.DateofPositiveResults?
      return @["Facility"].DateofPositiveResults
    else if @["USSD Notification"]?
      return @["USSD Notification"].date

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
