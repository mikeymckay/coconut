class ReportView extends Backbone.View
  initialize: ->
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
#    @locationTypes = "region, district, constituan, shehia".split(/, /)

#    _.each (@locationTypes), (option) ->
#      if options[option] is undefined
#        this[option] = "ALL"
#      else
#        this[option] = unescape(options[option])
    @reportType = options.reportType || "users"
    @startDate = options.startDate || moment(new Date).subtract('days',7).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")

    Coconut.questions.fetch
      include_docs:true
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

     
#    selectedLocations = {}
#    _.each @locationTypes, (locationType) ->
#      selectedLocations[locationType] = this[locationType]
#
#    _.each @locationTypes, (locationType,index) =>
#
#      $("#reportOptions").append @formFilterTemplate(
#        id: locationType
#        label: locationType.capitalize()
#        form: "
#          <select id='#{locationType}'>
#            #{
#              locationSelectedOneLevelHigher = selectedLocations[@locationTypes[index-1]]
#              _.map( ["ALL"].concat(@hierarchyOptions(locationType,locationSelectedOneLevelHigher)), (hierarchyOption) ->
#                "<option #{"selected='true'" if hierarchyOption is selectedLocations[locationType]}>#{hierarchyOption}</option>"
#              ).join("")
#            }
#          </select>
#        "
#      )


      $("#reportOptions").append @formFilterTemplate(
        id: "report-type"
        label: "Report Type"
        form: "
        <select id='report-type'>
          #{
            _.map(["spreadsheet","results","summarytables","users"], (type) =>
              "<option #{"selected='true'" if type is @reportType}>#{type}</option>"
            ).join("")
          }
        </select>
        "
      )

      this[@reportType]()

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

  viewQuery: (options) ->

    results = new ResultCollection()
    results.fetch
      question: $('#selected-question').val()
      isComplete: true
      include_docs: true
      success: ->
        results.fields = {}
        results.each (result) ->
          _.each _.keys(result.attributes), (key) ->
            results.fields[key] = true unless _.contains ["_id","_rev","question"], key
        results.fields = _.keys(results.fields)
        options.success(results)

  spreadsheet: ->

    $($("#reportOptions tr")[0]).hide()
    $("#reportOptions").after "
      <a id='csv' href='http://spreadsheet.coconutclinic.org/spreadsheet/#{@startDate}/#{@endDate}'>Download spreadsheet for #{@startDate} to #{@endDate}</a>
    "
    $("a#csv").button()

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





  users: ->
    @$el.append  "
      <table id='users' class='tablesorter'>
        <thead>
          <th>User</th>
          <th>Clinical Visit</th>
          <th>Demographic</th>
        </thead>
        <tbody>
        </tbody>
      </table>
    "

    aggregatedData = {
      "Total":
        "Clinical Visit": 0
        "Client Demographics": 0
    }

    users = new UserCollection()
    users.fetch
      include_docs: true
      success: =>
        users.each (user) =>
          aggregatedData[user.get("_id").replace(/user\./, "")] = {
            "Clinical Visit": 0
            "Client Demographics": 0
          }

        console.log aggregatedData

        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}-server/resultsByUser",
          startkey: @startDate
          endkey: moment(@endDate).endOf("day").format("YYYY-MM-DD HH:mm:ss") # include all entries for today
          success: (results) ->
            _(results.rows).each (result) ->
              if result.value[1] is "Clinical Visit" or result.value[1] is "Client Demographics"
                aggregatedData[result.value[0]][result.value[1]] += 1
                aggregatedData["Total"][result.value[1]] += 1
            $("table#users tbody").append(_(aggregatedData).map (countByQuestion, user) ->
              "
              <tr id='user-#{user}'>
                <td>#{user}</td>
                <td>#{countByQuestion["Clinical Visit"]}</td>
                <td>#{countByQuestion["Client Demographics"]}</td>
              </tr>
              "
            .join(""))
            $(".user-total").css("font-weight:bold")
            $("table#users").dataTable
              aaSorting: [[1,"desc"],[2,"desc"]]
              iDisplayLength: 25
            
              

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

        fields = _.without(fields, "_id", "_rev")
    
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

        console.log results
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
