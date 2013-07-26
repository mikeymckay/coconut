class ResultCollection extends Backbone.Collection
  model: Result
  url: '/result'
  db:
    view: "resultsByQuestionAndComplete"

  fetch: (options) ->
    # I am using z to mark the end of the match
    if options?.question
      options.startkey = options.question + ":z"
      options.endkey = options.question
      options.descending = "true"

      if options.isComplete is "trueAndFalse"
        @db.view = "resultsByQuestion"
        if options.startTime?
          options.startkey = options.question + ":" + options.startTime
          options.endkey = options.question
          options.descending = "true"
          if options.endTime?
            options.startkey = options.question + ":" + options.startTime
            options.endkey = options.question + ":" + options.endTime
            options.descending = "true"
      else if options.isComplete?
        options.startkey = options.question + ":" + options.isComplete + ":z"
        options.endkey = options.question + ":" + options.isComplete
        options.descending = "true"
        if options.startTime?
          options.startkey = options.question + ":" + options.isComplete + ":" + options.startTime
          options.endkey = options.question + ":" + options.isComplete
          options.descending = "true"
          if options.endTime?
            options.startkey = options.question + ":" + options.isComplete + ":" + options.startTime
            options.endkey = options.question + ":" + options.isComplete + ":" + options.endTime
            options.descending = "true"
    super(options)

  filteredByQuestionCategorizedByStatus: (questionType) ->
    returnObject = {}
    returnObject.complete = []
    returnObject.notCompete = []
    @each (result) ->
      return unless result.get("question") is questionType
      switch result.get("complete")
        when true
          returnObject.complete.push(result)
        else
          returnObject.notComplete.push(result)
          
    return returnObject

  filterByQuestionType: (questionType) ->
    @filter (result) ->
      return result.get("question") is questionType

  partialResults: (questionType) ->
    @filter (result) ->
      return result.get("question") is questionType and not result.complete()
