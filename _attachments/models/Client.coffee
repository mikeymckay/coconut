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
      else if resultDoc.source
        @clientID ?= resultDoc["IDLabel"].replace(/-|\n/g,"")
        @availableQuestionTypes.push resultDoc["source"]
        this[resultDoc["source"]] = [] unless this[resultDoc["source"]]?
        this[resultDoc["source"]].push resultDoc

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

  mostRecentValue: (resultType,question) =>
    returnVal = null
    if @[resultType]?
      for result in @[resultType]
        if result[question]?
          returnVal = result[question]
          break
    return returnVal

  mostRecentValueFromMapping: (mappings) =>
    returnVal = null
    for map in mappings
      returnVal = @mostRecentValue(map.resultType,map.question)
      console.log returnVal
      if returnVal?
        if map.postProcess?
          returnVal = map.postProcess(returnVal)
        break
    return returnVal

  hasClientDemographics: ->
    return @["Client Demographics"]? and @["Client Demographics"].length > 0

  hasTblDemography: ->
    return @['tblDemography']? and @['tblDemography'].length > 0
    
  hasDemographicResult: ->
    window.b = @
    console.log @hasClientDemographics()
    console.log @hasTblDemography()
    return @hasClientDemographics() or @hasTblDemography()

  initialVisitDate: ->
    postProcess = (value) -> moment(value).format(Coconut.config.get("date_format"))
    @mostRecentValueFromMapping [
      {
        resultType: "Client Demographics"
        question: "createdAt"
        postProcess: postProcess
      }
      {
        resultType: "tblDemography"
        question: "fDate"
        postProcess: postProcess
      }
    ]

  dateFromDateQuestions: (resultType,postfix) ->
    #_.keys
    #dateQuestions.yearOfBirth

  calculateAge: (birthDate, onDate = new Date()) ->
      # From http://stackoverflow.com/questions/4060004/calculate-age-in-javascript
      birthDate = new Date("#{yearOfBirth}-#{monthOfBirth}-#{dayOfBirth}")
      age = onDate.getFullYear() - birthDate.getFullYear()
      currentMonth = onDate.getMonth() - birthDate.getMonth()
      age-- if (currentMonth < 0 or (currentMonth is 0 and onDate.getDate() < birthDate.getDate()))
      return age

  currentAge: ->
    if @hasDemographicResult()
      yearOfBirth = @mostRecentValue("Client Demographics", "Whatisyouryearofbirth")
      monthOfBirth = @mostRecentValue("Client Demographics", "Whatisyourmonthofbirth")
      dayOfBirth = @mostRecentValue("Client Demographics", "Whatisyourdayofbirth")
      age = @mostRecentValue("Client Demographics", "Whatisyourage")

      if yearOfBirth?
        unless monthOfBirth?
          monthOfBirth = "June"
          dayOfBirth = "1"
        unless dayOfBirth?
          dayOfBirth = "15"
        return @calculateAge(new Date("#{yearOfBirth}-#{monthOfBirth}-#{dayOfBirth}"))
      else
        return age

    if @hasTblDemography()
      birthDate = @mostRecentValue "tblDemography", "DOB"
      if birthDate?
        return @calculateAge(new Date(birthDate))
      else
        return @mostRecentValue "tblDemography", "Age"

  hivStatus: ->
    #TODO should be checking test dates and using that as the basis for the most recent result
    @mostRecentValueFromMapping [
      {
        resultType: "Clinical Visit"
        question: "ResultofHIVtest"
      }
      {
        resultType: "Clinical Visit"
        question: "WhatwastheresultofyourlastHIVtest"
      }
      {
        resultType: "tblSTI"
        question: "HIVTestResult"
      }
    ]

#  onART: ->
#    "#{@mostRecentValue "Are Visit", "SystolicBloodPressure"}

  lastBloodPressure: ->
    "#{@mostRecentValue "Clinical Visit", "SystolicBloodPressure"}/#{@mostRecentValue "Clinical Visit", "DiastolicBloodPressure"}"

