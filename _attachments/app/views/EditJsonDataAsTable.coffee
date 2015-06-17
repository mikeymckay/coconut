class JsonDataAsTableView extends Backbone.View

  # Need @fields
  # Need @name
  # Need @document_id
  # Need @dataToColumns ->
  # Need @tableDataToJson ->

  el: '#content'

  render: =>
    @$el.html "
      <h1>#{@name}</h1>
      To change a value, click on it in the table and press save. You can also
      <button id='add' type='button'>Add A New Entry</button>.
      <div id='saveUndo' style='display:none'>
        <div style='color:red'>Note, data is not saved to the database until the save button is pressed</div>
        <button id='save' type='button'>Save</button>
        <button id='undo' type='button'>Undo</button>
      </div>
      <hr/>
      <table id='table_data'>
        <thead>
          #{_(@fields).map((field) -> "<th>#{field}</th>").join("")}
          <th>Delete</th>
        </thead>
        <tbody>
      </table>
    "
    
    Coconut.database.openDoc @document_id,
      error: (error) -> "Could not open: #{JSON.stringify error}"
      success: (result) =>

        @databaseDoc = result

        # dataToColumns should be defined elsewhere
        data = @dataToColumns(result)

        @$el.find("#table_data tbody").html(_(data).map (rowData, rowIdentifier) =>
            "
            <tr id='#{rowIdentifier}'>
              #{
                _(@fields).map (field) =>
                  "<td class='#{field.replace(" ", "_")}'>#{rowData[field]}</td>"
                .join()
              }
              <td class='delete'>x</td>
            </tr>
            "
          .join("")
        )
        @dataTable = $("#table_data").DataTable()
        @makeTableEditable()

  makeTableEditable: => $("#table_data").editableTableWidget({preventColumns: [@fields.length + 1]})

  events:
    "click #add" : "add"
    "click #save" : "save"
    "click #undo" : "undo"
    "click td.delete" : "delete"
    "change #table_data td" : "tableChange"
    "draw.dt #table_data" : "pageChange"


  pageChange: (event) ->
    _.delay @makeTableEditable, 1500

  tableChange: (event) ->
    $("#saveUndo").show()
    changedCell = $(event.target)
    @dataTable.cell(changedCell).data(changedCell.text())

  delete: (event) =>
    name = $(event.target).siblings('.Name').text()
    if confirm("Are you sure you want to delete #{name}")
      @dataTable.row($(event.target).closest('tr')).remove().draw()
      $("#saveUndo").show()

  add: =>
    @dataTable.row.add( _(@fields).map((field) -> " New #{field}").concat("x") ).draw()
    $("td:contains(x):not(.delete)").addClass("delete")
    @makeTableEditable()

  save: =>
    # updateDatabaseDoc should be implemented elsewhere
    @updateDatabaseDoc(@dataTable.data())
    Coconut.database.saveDoc @databaseDoc,
      success: =>  @render()

  undo: => @render()
