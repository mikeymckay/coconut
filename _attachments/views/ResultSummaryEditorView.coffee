class ResultSummaryEditorView extends Backbone.View
  initialize: ->

  el: $('#content')

  events:
    "submit #resultSummaryEditor form" : "save"

  save: ->
    @question.set
      resultSummaryFields : $('form').toObject()

    #newView = "
    #  if (document.collection == 'result' && document.question == '#{@question.get "_id"}'){
    #    emit(document.lastModifiedAt, [#{
    #      _.chain($('form')
    #        .toObject())
    #        .keys()
    #        .map (value) ->
    #          "document['#{value}']"
    #        .value()
    #        .join(",")
    #    }])
    #  }
    #  $.put "http://admin:password@localhost:5984/coconut/_design/coconut/_update/in-place/_design/coconut?field=README&value=shazam"
    #"
    @question.save()
    return false

  render: =>

    result = "
      <div id='resultSummaryEditor'>
        Check the boxes to use for summarizing results for <b>#{@question.id}</b>:<br/>
        <form>
          <ul>
      "
    _.each @question.questions(), (question,index) ->
      result += "
        <li>
          <input id='result-summary-option-#{index}' name='#{question.label()}' type='checkbox'></input>
          <label for='result-summary-option-#{index}'>#{question.label()}</label>
        </li>
      "
    result += "
          </ul>
          <input type='submit' value='Save'></input>
        </form>
      </div>
    "

    @$el.html result

    console.log @question


    js2form($('form').get(0), @question.resultSummaryFields())
