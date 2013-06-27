class DashboardView extends Backbone.View

  el: '#content'

  events:
    "change #reportOptions": "update"
#    "change #summaryField": "summarize"
#    "click #toggleDisaggregation": "toggleDisaggregation"

  update: =>
    reportOptions =
      startDate: $('#start').val()
      endDate: $('#end').val()
      reportType: $('#report-type :selected').text()

    _.each @locationTypes, (location) ->
      reportOptions[location] = $("##{location} :selected").text()

    url = "dashboard/" + _.map(reportOptions, (value, key) ->
      "#{key}/#{escape(value)}"
    ).join("/")

    Coconut.router.navigate(url,true)

  render: (options) =>
    @renderOptions(options)
    @renderDashboard()

    $('div[data-role=fieldcontain]').fieldcontain()
    $('select').selectmenu()
    $('input[type=date]').datebox {mode: "calbox"}

  renderOptions: (options) ->
    @startDate = options.startDate || moment(new Date).subtract('days',30).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")

    @$el.html "
      <style>
        table.results th.header, table.results td{
          font-size:150%;
        }

      </style>

      <table id='reportOptions'></table>
      "

    $("#reportOptions").append @formFilterTemplate(
      id: "start"
      label: "Start Date"
      form: "<input id='start' type='date' value='#{@startDate}'/>"
    )

    $("#reportOptions").append @formFilterTemplate(
      id: "end"
      label: "End Date"
      form: "<input id='end' type='date' value='#{@endDate}'/>"
    )

  formFilterTemplate: (options) ->
    "
      <tr id='row-#{options.id}' class='#{options.type}'>
        <td>
          <label style='display:inline' for='#{options.id}'>#{options.label}</label> 
        </td>
        <td style='width:150%'>
          #{options.form}
        </td>
      </tr>
    "

  renderDashboard: =>
    tableColumns = ["Time of Visit","User ID","Client ID","Location","Type of Visit"]
    @$el.append "
    <table id='dashboard' class='tablesorter'>
      <thead>
        <tr>
          #{
            _.map(tableColumns, (text) ->
              "<th>#{text}</th>"
            ).join("")
          }
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
    "

    @getClientResults
      success: (results) =>
        @$el.find("#dashboard tbody").append(_.map(results, (result) =>
          "
          <tr>
            <td>#{moment(result.key).format(Coconut.config.get("datetime_format"))}</td>
            <td>#{@extractUserID(result.doc)}</td>
            <td>#{@extractClientID(result.doc)}</td>
            <td>#{@extractLocation(result.doc)}</td>
            <td>#{@extractTypeOfVisit(result.doc)}</td>
          </tr>
          "
        ).join(""))

        $("#dashboard").tablesorter
          widgets: ['zebra']
          sortList: [[0,0]]


  extractUserID: (result) ->
    if result.user
      return result.user
    else if result.source
      return "Unknown"

  extractClientID: (result) ->
    if result.question
      return result.ClientID
    else if result.source
      return result.IDLabel

  extractLocation: (result) ->
    if result.ClinicLocation
      return result.ClinicLocation
    else
      return "Unknown"

  extractTypeOfVisit: (result) ->
    if result.source
      return result.source
    else if result.question
      return result.question

  getClientResults: (options) ->
  
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/clientsByVisitDate",
      # Note that these seem reversed due to descending order
      startkey: moment(@endDate).endOf("day").format(Coconut.config.get "datetime_format")
      endkey: @startDate
      descending: true
      include_docs: true
      success: (result) =>
        options.success(result.rows)
