class SearchResultsView extends Backbone.View
  initialize: ->

  el: '#content'

  events:
    "change #name" : "updateName"
    "change #facility" : "updateFacility"

  render: =>
    @$el.html "
      Name: <input id='name'></input>
      Facility: <input id='facility'></input>
      <br/>
      Results that match name and facility:
      <div id='intersection'>None</div>
      <table>
        <tr>
          <td id='names'></td>
          <td id='facilities'></td>
        </tr>
      </table>
    "

  updateName: ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByNames",
      startkey: $("#name").val()
      limit: 500
      include_docs: false
      success: (result) =>
        $("#names").html _.map(result.rows, (result) ->
          "<div id='#{result.id}'>#{result.key}</div>"
        ).join("")
        @updateIntersectionList()

  updateFacility: ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByFacilities",
      startkey: $("#facility").val()
      limit: 500
      include_docs: false
      success: (result) =>
        $("#facilities").html _.map(result.rows, (result) ->
          "<div id='#{result.id}'>#{result.key}</div>"
        ).join("")
        @updateIntersectionList()


  updateIntersectionList: ->
    names = _.pluck($("#names div"), "id")
    facilities =  _.pluck($("#facilities div"), "id")
    intersection = _.intersection(names,facilities)
    $("#intersection").html _.map(intersection, (id) ->
      "<div>#{id}</div>"
    ).join("")
    _.each $("#intersection div"), (div) ->
      div = $(div)
      $.couch.db(Coconut.config.database_name()).openDoc div.html(),
        {}
      ,
        success: (result) ->
         div.html "
          <small>
            <pre>
            #{JSON.stringify(result,null,2)}
            </pre>
          </small>
        "


