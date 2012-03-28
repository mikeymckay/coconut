class Result extends Backbone.Model
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
