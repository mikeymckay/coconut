class ResultsView extends Backbone.View
  initialize: ->
    @question = new Question()

  el: $('#content')

  render: =>
    # 3 options: edit partials, edit complete, create new
    console.log @question
    console.log @question.summaryFieldNames()
    @el.html "
      <h1>#{@question.id}</h1>
      <a href='#new/result/#{@question.id}'>Start new result</a>
      <h2>Partial Results</h2>
      <table class='results notComplete tablesorter'>
        <thead><tr>
          " + _.map(@question.summaryFieldNames(), (summaryField) ->
            "<th class='header'>#{summaryField}</th>"
          ).join("") + "
          <th></th>
        </tr></thead>
        <tbody>
        </tbody>
      </table>
      <h2>Complete Results</h2>
      <table class='results complete tablesorter'>
        <thead><tr>
          " + _.map(@question.summaryFieldNames(), (summaryField) ->
            "<th class='header'>#{summaryField}</th>"
          ).join("") + "
          <th></th>

        </tr></thead>
        <tbody>
        </tbody>
      </table>
    "

    Coconut.resultCollection ?= new ResultCollection()
    Coconut.resultCollection.fetch
      success: =>
        Coconut.resultCollection.each (result,index) =>
          result.fetch
            success: =>
              relevantKeys = @question.summaryFieldKeys()
              if relevantKeys.length is 0
                relevantKeys = _.difference (_.keys result.toJSON()), [
                  "_id"
                  "_rev"
                  "complete"
                  "question"
                  "collection"
                ]

              if result.question() is @question.id
                templateData = {
                  id: result.id
                  resultFields:  _.map relevantKeys, (key) =>
                    returnVal = result.get(key) || ""
                    if typeof returnVal is "object"
                      returnVal = JSON.stringify(returnVal)
                    returnVal
                }
                if result.complete()
                  $("table.Complete tbody").append(rowTemplate(templateData))
                else
                  $("table.notComplete tbody").append(rowTemplate(templateData))
  

              # Wait until all items have been added before adding the sorting/filtering
              if index+1 is Coconut.resultCollection.length
                $('table').tableFilter()
                $('table').tablesorter()

  rowTemplate = Handlebars.compile "
    <tr>
      {{#each resultFields}}
        <td>{{this}}</td>
      {{/each}}
      <td><a href='#edit/result/{{id}}'>Edit</a></td>
<!--
      <td><a href='#view/result/{{id}}'>View</a></td>
-->
    </tr>
  "

