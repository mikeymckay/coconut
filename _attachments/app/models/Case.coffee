class Case
  constructor: (options) ->
    @caseID = options?.caseID
    @loadFromResultArray(options.results) if options?.results

  loadFromResultArray: (results) ->
    @caseResults = results
    @questions = []
    this["Household Members"] = []
    @caseID = results[0].get "MalariaCaseID"
    _.each results, (result) =>
      if @caseID is not result.get "MalariaCaseID" then throw new Exception "Inconsistent Case ID"
      @questions.push result.get "question"
      if result.get("question") is "Household Members"
        this["Household Members"].push result.toJSON()
      else
        this[result.get "question"] = result.toJSON()

  fetch: (options) ->

    $.couch.db(Coconut.config.database_name()).view "zanzibar/cases"
      key: @caseID
      include_docs: true
      success: (result) =>

        @questions = []
        this["Household Members"] = []

        _.each result.rows, (row) =>
          if row.doc.question
            @questions.push row.doc.question
            if row.doc.question is "Household Members"
              this["Household Members"].push row.doc
            else
              console.error "#{@caseID} already has a result for #{row.doc.question} - needs cleaning" if this[row.doc.question]?
              this[row.doc.question] = row.doc
          else
            @questions.push "USSD Notification"
            this["USSD Notification"] = row.doc

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
    if @["USSD Notification"]?
      @["USSD Notification"].date
# Need to clean dates before I can show DateofPositiveResults
#    if @["Facility"]?.DateofPositiveResults?
#      @["Facility"].DateofPositiveResults
#    else if @["USSD Notification"]?
#      @["USSD Notification"].date

  householdMembersDiagnosisDate: ->
    returnVal = []
    _.each @["Household Members"]?, (member) ->
      returnVal.push member.lastModifiedAt if member.MalariaTestResult is "PF" or member.MalariaTestResult is "Mixed"
    
