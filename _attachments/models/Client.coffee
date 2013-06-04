class Client
  constructor: (options) ->
    @clientID = options?.clientID
    @loadFromResultDocs(options.results) if options?.results
    @availableQuestionTypes = []

  loadFromResultDocs: (resultDocs) ->
    @clientResults = resultDocs

    _.each resultDocs, (resultDoc) =>
      resultDoc = resultDoc.toJSON() if resultDoc.toJSON?

      if resultDoc.question
        @clientID ?= resultDoc["caseid"]
        @availableQuestionTypes.push resultDoc.question
        this[resultDoc.question] = [] unless this[resultDoc.question]?
        this[resultDoc.question].push resultDoc
      else # TODO handle MS Access imported data
        console.log resultDoc

    @sortResultArraysByCreatedAt()

  sortResultArraysByCreatedAt: () =>
    #TODO test with real data
    _.each @availableQuestionTypes, (resultType) =>
      @[resultType] = _.sortBy @[resultType], (result) ->
        result.createdAt

  fetch: (options) ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/clients",
      key: @clientID
      include_docs: true
      success: (result) =>
        @loadFromResultDocs(_.pluck(result.rows, "doc"))
        options?.success()
      error: =>
        options?.error()

  toJSON: =>
    returnVal = {}
    _.each @availableQuestionTypes, (question) =>
      returnVal[question] = this[question]
    return returnVal

  flatten: (availableQuestionTypes = @availableQuestionTypes) ->
    returnVal = {}
    _.each availableQuestionTypes, (question) =>
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

  mostRecentValue: (resultType,question) ->
    returnVal = null
    for result in @[resultType]?
      if result[question]?
        returnVal = result[question]
        break
    return returnVal

  hasDemographicResult: ->
    @["Client Demographics"]? and @["Client Demographics"].length > 0

  hivStatus: ->
    @mostRecentValue "Clinical Visit", "WhatwastheresultofyourlastHIVtest"

  lastBloodPressure: ->
    "#{@mostRecentValue "Clinical Visit", "SystolicBloodPressure"}/#{@mostRecentValue "Clinical Visit", "DiastolicBloodPressure"}"
