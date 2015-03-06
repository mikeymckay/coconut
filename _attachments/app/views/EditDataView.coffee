class EditDataView extends Backbone.View
  el: '#content'

  render: =>
    console.log @document
    @$el.html "
      <h1>Manage: #{@document._id.humanize()}</h1>

      <div>
        Year and month:
        <input type='month' id='month'></input>
        <textarea style='width:100%; height:400px' id='data'></textarea>
        <button type='button' id='save'>Save</button>
      </div>


      <div id='message'></div>
    "

  events:
    "click #save": "save"
    "change #month": "updateMonth"

  updateMonth: ->
    console.log  $('#month').val()
    console.log  @document[$('#month').val()]?.join("\n")
    $("#data").html @document[$('#month').val()]?.join("\n")

  save: ->
    data = _.compact $("#data").val().split("\n")
    @document[$('#month').val()] = data
    $.couch.db(Coconut.config.database_name()).saveDoc @document

    
