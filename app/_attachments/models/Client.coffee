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
        @clientID ?= resultDoc["IDLabel"]
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

  tblDemographyResultsOrClientDemographicResults: =>
    _.compact((@["tblDemography"] || []).concat(@["Client Demographics"]))

  tblSTIOrClinicalVisitResults: =>
    _.compact((@["tblSTI"] || []).concat(@["Clinical Visit"]))

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
      if returnVal?
        if map.postProcess?
          returnVal = map.postProcess(returnVal)
        break
    return returnVal


  mostRecentValueFromResultType: (resultType1,question1,resultType2,question2) ->
    @mostRecentValueFromMapping [
      {
        resultType: resultType1
        question: question1
      }
      {
        resultType: resultType2
        question: question2
      }
    ]

  mostRecentValueFromClientDemographicOrTblDemography: (question1,question2) ->
    @mostRecentValueFromResultType("Client Demographics",question1,"tblDemography",question2)

  mostRecentValueFromClinicalVisitOrTblSTI: (question1,question2) ->
    @mostRecentValueFromResultType("Clinical Visit",question1,"tblSTI",question2)

  allUniqueValues: (resultType, question, postProcess = null) =>
    if @[resultType]?
      _.chain(@[resultType])
      .map (result) ->
        if postProcess? and result[question]?
          postProcess(result[question])
        else
          result[question]
      .sort()
      .unique()
      .compact()
      .value()

  allUniqueValuesFromMapping: (mappings) =>
    _.chain(@[resultType])
    .map (result) ->
      @allUniqueValues(map.resultType,map.question,map.postProcess)
    .flatten()
    .unique()
    .compact()
    .value()

  allUniqueValuesFromResultType: (resultType1,question1,resultType2,question2) ->
    @allUniqueValuesFromMapping [
      {
        resultType: resultType1
        question: question1
      }
      {
        resultType: resultType2
        question: question2
      }
    ]

  allUniqueValuesFromClientDemographicAndTblDemography: (question1,question2) ->
    @allUniqueValuesFromResultType("Client Demographics",question1,"tblDemography",question2)

  allUniqueValuesFromClinicalVisitAndTblSTI: (question1,question2) ->
    @allUniqueValuesFromResultType("Clinical Visit",question1,"tblSTI",question2)

  allQuestionsWithResult: (resultType, questions, resultToMatch, postProcess = null) ->
    if @[resultType]?
      _.chain(@[resultType])
      .map (result) ->
        _.map questions, (question) ->
          if result[question] is resultToMatch
            if postProcess?
              return postProcess(question)
            else
              return question
      .flatten()
      .sort()
      .unique()
      .compact()
      .value()

  allQuestionsWithYesResult: (resultType, questions, postProcess = null) ->
    @allQuestionsWithResult(resultType,questions,"Yes", postProcess)

  allQuestionsMatchingNameWithResult: (resultType, questionMatch, resultToMatch, postProcess = null) ->
    questions = _.chain(@[resultType])
      .map (result) ->
        _.map result, (answer,question) ->
          if question.match(questionMatch) and answer is resultToMatch
            if postProcess?
              return postProcess(question)
            else
              return question
      .flatten()
      .sort()
      .unique()
      .compact()
      .value()
    window.a = questions
    questions

  allQuestionsMatchingNameWithYesResult: (resultType, questionMatch, postProcess = null) ->
    @allQuestionsMatchingNameWithResult(resultType,questionMatch,"Yes", postProcess)

  allAnswersMatchingQuestionNameForResult: (result, questionMatch, postProcess = null) ->
    _.chain(result)
      .map( (answer,question) ->
        return answer if question.match(questionMatch)
      )
      .compact()
      .value()

  hasClientDemographics: ->
    return @["Client Demographics"]? and @["Client Demographics"].length > 0

  hasTblDemography: ->
    return @['tblDemography']? and @['tblDemography'].length > 0
    
  hasDemographicResult: ->
    return @hasClientDemographics() || @hasTblDemography()

  mostRecentClinicalVisit: ->
    if @["Clinical Visit"]?
      _.max(@["Clinical Visit"], (result) ->
        moment(result["createdAt"]).unix()
      )

  mostRecentTblSTI: ->
    if @["tblSTI"]?
      # Need to parse the date and turn into timestamp
      return _.max(@["Clinical Visit"], (result) -> moment(result["Visit Date"]).unix())

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
      age = onDate.getFullYear() - birthDate.getFullYear()
      currentMonth = onDate.getMonth() - birthDate.getMonth()
      age-- if (currentMonth < 0 or (currentMonth is 0 and onDate.getDate() < birthDate.getDate()))
      return age

  currentAge: ->
    if @hasClientDemographics()
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
        #TODO calculate this based on date that age was recorded
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

  onArt: ->
    #TODO map 2 to something
    @mostRecentValueFromClinicalVisitOrTblSTI("AreyoucurrentlytakingARV","ARVTx")

  lastBloodPressure: ->
    systolic = @mostRecentValueFromClinicalVisitOrTblSTI("SystolicBloodPressure","BPSystolic")
    diastolic = @mostRecentValueFromClinicalVisitOrTblSTI("DiastolicBloodPressure","BPDiastolic")

    if systolic? and diastolic?
      return "#{systolic}/#{diastolic}"
    else
      return "-"

  allergies: ->
    _.union(
      @allQuestionsMatchingNameWithYesResult("Clinical Visit", "Allergy", (question) -> question.replace(/Allergyto/,""))
      @allUniqueValues("tblSTI","Allergies")
    ).join(", ")

  complaintsAtPreviousVisit: ->
    mostRecentClinicalVisit = @mostRecentClinicalVisit()
    if mostRecentClinicalVisit?
      return @allAnswersMatchingQuestionNameForResult(mostRecentClinicalVisit, /Complaint/i).join(", ")

    mostRecentTblSTI = @mostRecentTblSTI()
    if mostRecentTblSTI?
      #TODO handle symptom mappings
      return @allAnswersMatchingQuestionNameForResult(mostRecentTblSTI, "Symptom").join(", ")

  treatmentGivenAtPreviousVIsit: ->
    mostRecentClinicalVisit = @mostRecentClinicalVisit()
    if mostRecentClinicalVisit?
      return @allAnswersMatchingQuestionNameForResult(mostRecentClinicalVisit, "Treatment").join(", ")

    mostRecentTblSTI = @mostRecentTblSTI()
    if mostRecentTblSTI?
      #TODO handle mappings
      return @allAnswersMatchingQuestionNameForResult(mostRecentTblSTI, "Treat").join(", ")
