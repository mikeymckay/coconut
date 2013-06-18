class ResultCollection extends Backbone.Collection
  model: Result
  url: '/result'
  db:
    view: "resultsByQuestionAndComplete"

  fetch: (options) ->
    console.log options
    # I am using z to mark the end of the match
    if options?.question
      options.startkey = options.question + ":z"
      options.endkey = options.question
      options.descending = "true"
    if options?.question and options?.isComplete
      options.startkey = options.question + ":" + options.isComplete + ":z"
      options.endkey = options.question + ":" + options.isComplete
      options.descending = "true"
    if options?.question and options?.isComplete and options.startTime?
      options.startkey = options.question + ":" + options.isComplete + ":" + options.startTime
      options.endkey = options.question + ":" + options.isComplete
      options.descending = "true"
    if options?.question and options?.isComplete and options.startTime and options.endTime
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
