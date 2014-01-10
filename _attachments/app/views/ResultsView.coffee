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
        .dataTables_wrapper .dataTables_length{
          display: none;
        }

        .dataTables_filter input{
          display:inline;
          width:300px;
        }


        a[role=button]{
          background-color: white;
          margin-right:5px;
          -moz-border-radius: 1em;
          -webkit-border-radius: 1em;
          border: solid gray 1px;
          font-family: Helvetica,Arial,sans-serif;
          font-weight: bold;
          color: #222;
          text-shadow: 0 1px 0 #fff;
          -webkit-background-clip: padding-box;
          -moz-background-clip: padding;
          background-clip: padding-box;
          padding: .6em 20px;
          text-overflow: ellipsis;
          overflow: hidden;
          white-space: nowrap;
          position: relative;
          zoom: 1;
        }

        a[role=button].paginate_disabled_previous, a[role=button].paginate_disabled_next{
          color:gray;
        }

        .dataTables_info{
          float:right;
        }

        .dataTables_paginate{
          margin-bottom:20px;
        }


      </style>

      <a href='#new/result/#{escape(@question.id)}'>Add new '#{@question.id}'</a>
      <div class='not-complete' data-collapsed='false' data-role='collapsible'>
        <h2>'#{@question.id}' Items Not Completed (<span class='count-complete-false'></span>)</h2>
        <table class='results complete-false tablesorter'>
          <thead><tr>
            " + _.map(@question.summaryFieldNames(), (summaryField) ->
              "<th class='header'>#{summaryField}</th>"
            ).join("") + "
            <th></th>
          </tr></thead>
          <tbody>
          </tbody>
          <tfoot><tr>
            " + _.map(@question.summaryFieldNames(), (summaryField) ->
              "<th class='header'>#{summaryField}</th>"
            ).join("") + "
            <th></th>
          </tr></tfoot>
        </table>
      </div>
      <div class='complete' data-role='collapsible'>
        <h2>'#{@question.id}' Items Completed (<span class='count-complete-true'></span>)</h2>
        <table class='results complete-true tablesorter'>
          <thead><tr>
            " + _.map(@question.summaryFieldNames(), (summaryField) ->
              "<th class='header'>#{summaryField}</th>"
            ).join("") + "
            <th></th>

          </tr></thead>
          <tbody>
          </tbody>
          <tfoot><tr>
            " + _.map(@question.summaryFieldNames(), (summaryField) ->
              "<th class='header'>#{summaryField}</th>"
            ).join("") + "
            <th></th>

          </tr></tfoot>
        </table>
      </div>
    "

    $("a").button()
    
    #$('table').tablesorter()
    #$('table').addTableFilter
    #  labelText: null



    $('[data-role=collapsible]').collapsible()
    $('.complete').bind "expand", =>
      @loadResults("true") unless $('.complete tr td').length > 0

    @loadResults("false")
    @updateCountComplete()

  updateCountComplete: ->
    results = new ResultCollection()
    results.fetch
      question: @question.id
      isComplete: "true"
      success: =>
        $(".count-complete-true").html results.length
  
  loadResults: (complete) ->
    results = new ResultCollection()
    results.fetch
      include_docs: "true"
      question: @question.id
      isComplete: complete
      success: =>
        $(".count-complete-#{complete}").html results.length
        results.each (result,index) =>

          $("table.complete-#{complete} tbody").append "
            <tr>
              #{_.map(result.summaryValues(@question), (value) ->
                "<td><a href='#edit/result/#{result.id}'>#{value}</a></td>"
              ).join("")
              }
              <td><a href='#delete/result/#{result.id}' data-icon='delete' data-iconpos='notext'>Delete</a></td>
            </tr>
          "
  
          if index+1 is results.length
            $("table a").button()
            $("table").trigger("update")
          _.each $('table tr'), (row, index) ->
            $(row).addClass("odd") if index%2 is 1


        $('table').dataTable()

        $(".dataTables_filter input").textinput()
