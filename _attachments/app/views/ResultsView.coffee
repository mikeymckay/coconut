class ResultsView extends Backbone.View
  initialize: ->
    @question = new Question()

  el: '#content'

  render: =>
    # 3 options: edit partials, edit complete, create new
    @$el.html "
      <style>
        table.results th.header, table.results td{
          font-size:150%;
        }

      </style>

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
      <a href='#new/result/#{@question.id}'>Add new result</a>
    "

    $("a").button()

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
                  $("table a").button()
                else
                  $("table.notComplete tbody").append(rowTemplate(templateData))
                  $("table a").button()
  

              # Wait until all items have been added before adding the sorting/filtering
              if index+1 is Coconut.resultCollection.length
                $('table').addTableFilter
                  labelText: null
                $('table').tablesorter()
                $("input[type=search]").textinput()

  rowTemplate = Handlebars.compile "
    <tr>
      {{#each resultFields}}
        <td><a href='#edit/result/{{../id}}'>{{this}}</a></td>
      {{/each}}
      <td><a href='#delete/result/{{id}}' data-icon='delete' data-iconpos='notext'>Delete</a></td>
<!--
      <td><a href='#edit/result/{{id}}'>Edit</a></td>
      <td><a href='#view/result/{{id}}'>View</a></td>
-->
    </tr>
  "

