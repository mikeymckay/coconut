class ReportView extends Backbone.View

  el: "#content"

  events:
    "keyup #search" : "filter"

  initialize: (options) ->

    @[key] = value for key, value of options

    console.log @quid

    results = new Backbone.Collection
    results.model = Result
    results.url = "result"
    results.fetch
      success: (allResults) =>
        console.log allResults.first()
        window.allResults = allResults
        console.log "trying to get all from"
        console.log @quid
        @results = allResults.where
          "question" : @quid

        fields = _.chain(@results)
            .map (result) ->
              _.keys(result.attributes)
            .flatten()
            .uniq()
            .value()

        @fields = _(fields).without("_id", "_rev","test","question","collection")

        @render()

  filter: (event) ->
    query = @$el.find("#search").val()
    for id, row of @searchRows
      if ~row.indexOf(query) or query.length < 3
        @$el.find(".row-#{id}").show()
      else
        @$el.find(".row-#{id}").hide()

  render: ->

    @searchRows = {}

    html = "<input type='text' id='search' placeholder='filter'>"

    html += "<table class='tablesorter'>
      <thead>
        <tr>"
    for field in @fields
      html += "<th>#{field}</th>"
    html += "</tr></thead>
    <tbody>"


    for result in @results
      html += "<tr class='row-#{result.id}'>"
      @searchRows[result.id] = ""
      for field in @fields
        html += "<td>#{result.get(field)}</td>"
        @searchRows[result.id] += result.get(field)

      html += "</tr>"
    "</tbody></table>"

    @$el.html html


    $('table tr').each (index, row) ->
      $(row).addClass("odd") if index % 2 is 1


class OldReportView extends Backbone.View
  initialize: (options) ->


    @quid = options.quid


    $("html").append "
      <link href='js-libraries/Leaflet/leaflet.css' type='text/css' rel='stylesheet' />
      <script type='text/javascript' src='js-libraries/Leaflet/leaflet.js'></script>
      <style>
        .dissaggregatedResults{
          display: none;
        }
      </style>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"
    "change #summaryField": "summarize"
    "click #toggleDisaggregation": "toggleDisaggregation"

  update: =>
    reportOptions =
      startDate: $('#start').val()
      endDate: $('#end').val()
      reportType: $('#report-type :selected').text()

    _.each @locationTypes, (location) ->
      reportOptions[location] = $("##{location} :selected").text()

    url = "reports/" + _.map(reportOptions, (value, key) ->
      "#{key}/#{escape(value)}"
    ).join("/")

    Coconut.router.navigate(url,true)

  render: (options) =>

    @reportType = options.reportType || "results"
    @startDate  = options.startDate  || moment(new Date).subtract('days',30).format("YYYY-MM-DD")
    @endDate    = options.endDate    || moment(new Date).format("YYYY-MM-DD")

    Coconut.questions.fetch
      success: =>

      @$el.html "
        <style>
          table.results th.header, table.results td{
            font-size:150%;
          }

        </style>

        <table id='reportOptions'></table>
        "

        $("#reportOptions").append @formFilterTemplate(
          id: "question"
          label: "Question"
          form: "
              <select id='selected-question'>
                #{
                  Coconut.questions.map( (question) ->
                    "<option>#{question.label()}</option>"
                  ).join("")
                }
              </select>
            "
        )

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


      $("#reportOptions").append @formFilterTemplate(
        id: "report-type"
        label: "Report Type"
        form: "
        <select id='report-type'>
          #{
            _.map(["spreadsheet","results","summarytables"], (type) =>
              "<option #{"selected='true'" if type is @reportType}>#{type}</option>"
            ).join("")
          }
        </select>
        "
      )

      @[@reportType]()

      $('div[data-role=fieldcontain]').fieldcontain()
      $('select').selectmenu()
      $('input[type=date]').datebox {mode: "calbox"}


  hierarchyOptions: (locationType, location) ->
    if locationType is "region"
      return _.keys WardHierarchy.hierarchy
    _.chain(WardHierarchy.hierarchy)
      .map (value,key) ->
        if locationType is "district" and location is key
          return _.keys value
        _.map value, (value,key) ->
          if locationType is "constituan" and location is key
            return _.keys value
          _.map value, (value,key) ->
            if locationType is "shehia" and location is key
              return value
      .flatten()
      .compact()
      .value()

  mostSpecificLocationSelected: ->
    mostSpecificLocationType = "region"
    mostSpecificLocationValue = "ALL"
    _.each @locationTypes, (locationType) ->
      unless this[locationType] is "ALL"
        mostSpecificLocationType = locationType
        mostSpecificLocationValue = this[locationType]
    return {
      type: mostSpecificLocationType
      name: mostSpecificLocationValue
    }

  formFilterTemplate: (options) ->
    "
        <tr>
          <td>
            <label style='display:inline' for='#{options.id}'>#{options.label}</label> 
          </td>
          <td style='width:150%'>
            #{options.form}
            </select>
          </td>
        </tr>
    "

  viewQuery: (options) =>

    results = new ResultCollection()
    results.fetch
      question: @quid
      isComplete: true
      include_docs: true
      success: ->
        results.fields = {}
        results.each (result) ->
          _.each _.keys(result.attributes), (key) ->
            results.fields[key] = true unless _.contains ["_id","_rev","question"], key
        results.fields = _.keys(results.fields)
        options.success(results)

  results: ->
    @$el.append  "
      <table id='results' class='tablesorter'>
        <thead>
          <tr>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    "

    @viewQuery
      success: (results) =>
        window.theseResults = results

        tableData = results.map (result) ->
          _.map results.fields, (field) ->
            result.get field

        $("table#results thead tr").append "
          #{ _.map(results.fields, (field) ->
            "<th>#{field}</th>"
          ).join("")
          }
        "

        $("table#results tbody").append _.map(tableData, (row) ->  "
          <tr>
            #{_.map(row, (element,index) -> "
              <td>#{element}</td>
            ").join("")
            }
          </tr>
        ").join("")

        _.each $('table tr'), (row, index) ->
          $(row).addClass("odd") if index%2 is 1

  spreadsheet: =>
    @viewQuery
      success: (results) =>
        console.log results

        csvData = results.map( (result) ->
          _.map(results.fields, (field) ->
            result.get field
          ).join ","
        ).join "\n"

        @$el.append "
          <a id='csv' href='data:text/octet-stream;base64,#{Base64.encode(results.fields.join(",") + "\n" + csvData)}' download='#{@startDate+"-"+@endDate}.csv'>Download spreadsheet</a>
        "
        $("a#csv").button()

  summarytables: ->
    Coconut.resultCollection.fetch
      includeData: true
      success: =>

        fields = _.chain(Coconut.resultCollection.toJSON())
        .map (result) ->
          _.keys(result)
        .flatten()
        .uniq()
        .sort()
        .value()

        fields = _(fields).without("_id", "_rev")
    
        @$el.append  "
          <br/>
          Choose a field to summarize:<br/>
          <select id='summaryField'>
            #{
              _.map(fields, (field) ->
                "<option id='#{field}'>#{field}</option>"
              ).join("")
            }
          </select>
        "
        $('select').selectmenu()


  summarize: ->
    field = $('#summaryField option:selected').text()

    @viewQuery
      success: (resultCollection) =>

        results = {}

        resultCollection.each (result) ->
          _.each result.toJSON(), (value,key) ->
            if key is field
              if results[value]?
                results[value]["sums"] += 1
                results[value]["resultIDs"].push result.get "_id"
              else
                results[value] = {}
                results[value]["sums"] = 1
                results[value]["resultIDs"] = []
                results[value]["resultIDs"].push result.get "_id"

        @$el.append  "
          <h2>#{field}</h2>
          <table id='summaryTable' class='tablesorter'>
            <thead>
              <tr>
                <th>Value</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              #{
                _.map( results, (aggregates,value) ->
                  "
                  <tr>
                    <td>#{value}</td>
                    <td>
                      <button id='toggleDisaggregation'>#{aggregates["sums"]}</button>
                    </td>
                    <td class='dissaggregatedResults'>
                      #{
                        _.map(aggregates["resultIDs"], (resultID) ->
                          resultID
                        ).join(", ")
                      }
                    </td>
                  </tr>
                  "
                ).join("")
              }
            </tbody>
          </table>
        "
        $("button").button()
        $("a").button()
        _.each $('table tr'), (row, index) ->
          $(row).addClass("odd") if index%2 is 1


  toggleDisaggregation: ->
    $(".dissaggregatedResults").toggle()

#  locations: ->
#    @$el.append "
#      <div id='map' style='width:100%; height:600px;'></div>
#    "
#
#    @viewQuery
#      # TODO use Cases, map notificatoin location too
#      success: (results) =>
#
#        locations = _.compact(_.map results, (caseResult) ->
#          if caseResult.Household?["HouseholdLocation-latitude"]
#            return {
#              MalariaCaseID: caseResult.caseId
#              latitude: caseResult.Household?["HouseholdLocation-latitude"]
#              longitude: caseResult.Household?["HouseholdLocation-longitude"]
#            }
#        )
#
#        if locations.length is 0
#          $("#map").html "
#            <h2>No location information for the range specified.</h2>
#          "
#          return
#
#        map = new L.Map('map', {
#          center: new L.LatLng(
#            locations[0]?.latitude,
#            locations[0]?.longitude
#          )
#          zoom: 9
#        })
#
#        map.addLayer(
#          new L.TileLayer(
#            'http://{s}.tile.cloudmade.com/4eb20961f7db4d93b9280e8df9b33d3f/997/256/{z}/{x}/{y}.png',
#            {maxZoom: 18}
#          )
#        )
#
#        _.each locations, (location) =>
#          map.addLayer(
#            new L.CircleMarker(
#              new L.LatLng(location.latitude, location.longitude)
#            )
#          )
