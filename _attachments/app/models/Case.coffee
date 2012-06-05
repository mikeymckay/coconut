class Case
  constructor: (options) ->
    @caseID = options?.caseID
    if options?.results
      @loadFromResultArray(options.results)


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
    Coconut.ResultCollection ?= new ResultCollection()
    Coconut.ResultCollection.fetch
      success: =>
        @loadFromResultArray(Coconut.ResultCollection.where
          MalariaCaseID: @caseID
        )
        options.success()

  toJSON: =>
    returnVal = {}
    _.each @questions, (question) =>
      returnVal[question] = this[question]
    return returnVal
    
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

  region: ->
    WardHierarchy.region(@questions["Case Notification"]["FacilityName"])
