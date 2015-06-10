class RainfallStationsView extends Backbone.View
  el: '#content'

  render: ->

    @fields = "Region,District,Name,Phone Numbers".split(/,/)
    
    @$el.html "
      <h1>Rainfall Stations</h1>
      To change a value, click on it in the table and press save. You can also
      <button id='add' type='button'>Add A New Entry</button>.
      <div id='saveUndo' style='display:none'>
        <div style='color:red'>Note, data is not saved to the database until the save button is pressed</div>
        <button id='save' type='button'>Save</button>
        <button id='undo' type='button'>Undo</button>
      </div>
      <hr/>
      <table id='rainfall_stations'>
        <thead>
          #{_(@fields).map((field) -> "<th>#{field}</th>").join("")}
          <th>Delete</th>
        </thead>
        <tbody>
      </table>
    "
    
    Coconut.database.openDoc "Rainfall Stations",
      error: (error) -> "Could not open: #{JSON.stringify error}"
      success: (result) =>
        @databaseDoc = result
        data = {}
        _(result.data).each (stationData,stationName) =>
          _(@fields).each (field) =>
            data[stationName] = {} unless data[stationName]?
            data[stationName][field] = stationData[field]
          data[stationName]["Name"] = stationName
          data[stationName]["Phone Numbers"] = data[stationName]["Phone Numbers"].join(",")

         @$el.find("#rainfall_stations tbody").html(_(data).map (stationData, stationName) =>
            "
            <tr id='#{stationName}'>
              #{
                _(@fields).map (field) =>
                  "<td class='#{field.replace(" ", "_")}'>#{stationData[field]}</td>"
                .join()
              }
              <td class='delete'>x</td>
            </tr>
            "
          .join("")
        )
        @dataTable = $("#rainfall_stations").DataTable()
        @makeTableEditable()

  makeTableEditable: -> $("#rainfall_stations").editableTableWidget({preventColumns: [5]})

  events:
    "click #add" : "add"
    "click #save" : "save"
    "click #undo" : "undo"
    "click td.delete" : "delete"
    "change #rainfall_stations td" : "showSaveUndo"

  showSaveUndo: -> $("#saveUndo").show()

  delete: (event) =>
    name = $(event.target).siblings('.Name').text()
    if confirm("Are you sure you want to delete #{name}")
      @dataTable.row($(event.target).closest('tr')).remove().draw()
      $("#saveUndo").show()

  add: =>
    @dataTable.row.add( _(@fields).map((field) -> "New #{field}").concat("x") ).draw()
    $("td:contains(x):not(.delete)").addClass("delete")
    @makeTableEditable()

  save: =>
    dataFromTable = _($("#rainfall_stations tbody tr")).map (tr) ->
       _($(tr).find("td")).map (td) -> $(td).text()

    dataToSave = {}
    _(dataFromTable).each (row) ->
      dataToSave[row[2]] = {
        Region: row[0]
        District: row[1]
        "Phone Numbers": row[3].split(",")
      }

    @updateDatabase dataToSave

  undo: => @render()

  updateDatabase: (document) =>
    @databaseDoc.data = document

    Coconut.database.saveDoc @databaseDoc,
      success: =>  @render()
