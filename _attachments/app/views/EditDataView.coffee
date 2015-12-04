class EditDataView extends Backbone.View
  el: '#content'

  render: =>
    @$el.html "
      <h1>Manage: #{@document._id.humanize()}</h1>

      Select the year and month for the data that will be entered. Then list she relevant shehias, with one on each line (pasting from a spreadsheet should work fine).

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
    $("#data").html @document[$('#month').val()]?.join("\n")

  save: ->
    $("#message").html ""
    data = _.compact $("#data").val().split("\n")
    allShehiasValid = true
    _(data).each (shehia) ->
      if GeoHierarchy.findShehia(shehia).length is 0
        allShehiasValid = false
        $("#message").append "#{shehia} is not a valid shehia<br/>"
    if allShehiasValid
      @document[$('#month').val()] = data
      $.couch.db(Coconut.config.database_name()).saveDoc @document,
        error: (error) ->
          $("#message").append "Error while saving data: #{JSON.stringify error}"
        success: ->
          $("#message").append "Shehia list is valid, data saved"
    else
      alert "Shehia list is not valid, must resolve before saving."

    
