class Result extends Backbone.Model
  initialize: ->
    unless this.attributes.createdAt
      @set
        createdAt: moment(new Date()).format(Coconut.config.get "date_format")
    unless this.attributes.lastModifiedAt
      @set
        lastModifiedAt: moment(new Date()).format(Coconut.config.get "date_format")

  url: "/result"

  question: ->
    return @get("question")

  tags: ->
    tags = @get("Tags")
    return tags.split(/, */) if tags?
    return []

  complete: ->
    return true if _.include(@tags(), "complete")
    complete = @get("complete")
    complete = @get("Complete") if typeof complete is "undefined"
    return false if complete is null or typeof complete is "undefined"
    return true if complete is true or complete.match(/true|yes/)

  shortString: ->
    # see ResultsView.coffee to see @string get set
    result = @string
    if result.length > 40 then result.substring(0,40) + "..." else result

  summaryKeys: (question) ->
          
    relevantKeys = question.summaryFieldKeys()
    if relevantKeys.length is 0
      relevantKeys = _.difference (_.keys result.toJSON()), [
        "_id"
        "_rev"
        "complete"
        "question"
        "collection"
      ]

    return relevantKeys

  summaryValues: (question) ->
    return _.map @summaryKeys(question), (key) =>
      console.log key if key.match /RDT/
      returnVal = @get(key) || ""
      if typeof returnVal is "object"
        returnVal = JSON.stringify(returnVal)
      returnVal
  
  get: (attribute) ->
    return null unless User.currentUser?
    original = super(attribute)
    if original? and User.currentUser.hasRole "reports"
      if _.contains(Coconut.identifyingAttributes, attribute)
        return b64_sha1(original)

    return original

  toJSON: ->
    json = super()
    if User.currentUser.hasRole "reports"
      _.each json, (value, key) =>
        if value? and _.contains(Coconut.identifyingAttributes, key)
          json[key] = b64_sha1(value)

    return json

  save: (key,value,options) ->
    @set
      user: $.cookie('current_user')
      lastModifiedAt: moment(new Date()).format(Coconut.config.get "date_format")
    super(key,value,options)
