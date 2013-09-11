class Question extends Backbone.Model
  hint: -> @safeGet('hint', '')
  type: -> @safeGet("type", "text")
  label: -> @safeGet("label", @get('id'))
  safeLabel: -> @label().replace(/[^a-zA-Z\u00E0-\u00FC0-9 -]/g,"").replace(/[ -]/g,"")
  repeatable: -> @get("repeatable") is"true" or @get("repeatable") is true
  questions: -> @safeGet("questions", [])
  skipLogic: -> @safeGet("skip_logic", '')
  actionOnChange: -> @safeGet("action_on_change", '')
  actionOnQuestionsLoaded: -> @safeGet("action_on_questions_loaded", '')

  value: -> @safeGet("value", "")
  required: -> @safeGet("required", true)
  validation: -> @safeGet("validation", null)
  warning: -> @safeGet("warning", null)

  attributeSafeText: ->
    returnVal = @safeGet("label", @get('id'))
    returnVal.replace(/[^a-zA-Z\u00E0-\u00FC0-9]/g,"")

  url: "/question"

  get: (key) ->
    if key == "id" then return @get("_id")
    super(key)

  safeGet: ( attribute, defaultValue ) ->
    value = @get(attribute)
    return value if value?
    return defaultValue

  set: (attributes) ->
    if attributes.questions?
      attributes.questions =  _.map attributes.questions, (question) ->
        new Question(question)
    attributes._id = attributes.id if attributes.id?
    super(attributes)

  loadFromDesigner: (domNode) ->
    result = Question.fromDomNode(domNode)
# TODO is this always going to just be the root question - containing only a name?
    if result.length is 1
      result = result[0]
      @set { id : result.id }
      for property in ["label","type","repeatable","required","validation"]
        attribute = {}
        attribute[property] = result.get(property)
        @set attribute
      @set {questions: result.questions()}
    else
      throw "More than one root node"

  resultSummaryFields: =>
    resultSummaryFields = @get("resultSummaryFields")
    if resultSummaryFields
      return resultSummaryFields
    else
      # If this hasn't been defined, default to first 3 fields if it has that many
      numberOfFields = Math.min(2,@questions().length-1)
      returnValue = {}
      _.each([0..numberOfFields], (index) =>
        returnValue[@questions()[index]?.label()] = "on"
      )
      return returnValue

  summaryFieldNames: =>
    return _.keys @resultSummaryFields()

  summaryFieldKeys: ->
    return _.map @summaryFieldNames(), (key) ->
      key.replace(/[^a-zA-Z0-9 -]/g,"").replace(/[ -]/g,"")

#Recursive
Question.fromDomNode = (domNode) ->
  _(domNode).chain()
    .map (question) =>
      question = $(question)
      id = question.attr("id")
      if question.children("#rootQuestionName").length > 0
        id = question.children("#rootQuestionName").val()
      return unless id
      result = new Question
      result.set { id : id }
      for property in ["label","type","repeatable","select-options","radio-options","autocomplete-options","validation","required", "action_on_questions_loaded", "skip_logic", "action_on_change", "image-path", "image-style"]
        attribute = {}
        # Note that we are using find but the id property ensures a proper match
        propertyValue = question.find("##{property}-#{id}").val()
        propertyValue = String(question.find("##{property}-#{id}").is(":checked")) if property is "required"
        if propertyValue?
          attribute[property] = propertyValue
          result.set attribute

      result.set
        safeLabel: result.safeLabel()
        
      if question.find(".question-definition").length > 0
        result.set {questions: Question.fromDomNode(question.children(".question-definition"))}
      return result
    .compact().value()

