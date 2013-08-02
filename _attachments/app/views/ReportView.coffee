class ReportView extends Backbone.View
  initialize: ->
    $("html").append "

      <style>
        .cases{
          display: none;
USSD}
      </style>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"
    "change #summaryField1": "summarySelectorChanged"
    "change #summaryField2": "summarySelector2Changed"
    "change #cluster": "update"
    "click .toggleDisaggregation": "toggleDisaggregation"
    "click .same-cell-disaggregatable": "toggleDisaggregationSameCell"
    "click .toggle-trend-data": "toggleTrendData"

  toggleTrendData: ->
    if $(".toggle-trend-data").html() is "Show trend data"
      $(".data").show()
      $(".toggle-trend-data").html "Hide trend data"
    else
      $(".data").hide()
      $(".period-0.data").show()
      $(".toggle-trend-data").html "Show trend data"

  hideSublocations: ->
    hide=false
    _.each @locationTypes, (location) ->
      if hide
        $("#row-#{location}").hide()
      if $("##{location}").val() is "ALL"
        hide = true

  update: =>
    reportOptions =
      startDate: $('#start').val()
      endDate: $('#end').val()
      reportType: $('#report-type :selected').text()
      cluster: $("#cluster").val()
      summaryField1: $("#summaryField1").val()

    _.each @locationTypes, (location) ->
      reportOptions[location] = $("##{location} :selected").text()

    url = "reports/" + _.map(reportOptions, (value, key) ->
      "#{key}/#{escape(value)}"
    ).join("/")

    Coconut.router.navigate(url,true)

  render: (options) =>
    @reportOptions = options
    @locationTypes = "region, district, constituan, shehia".split(/, /)

    _.each (@locationTypes), (option) ->
      if options[option] is undefined
        this[option] = "ALL"
      else
        this[option] = unescape(options[option])
    @reportType = options.reportType || "dashboard"
    @startDate = options.startDate || moment(new Date).subtract('days',7).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")
    @cluster = options.cluster || "off"
    @summaryField1 = options.summaryField1

    @$el.html "
      <style>
        table.results th.header, table.results td{
          font-size:150%;
        }
        .malaria-positive{
          background-color: pink;
        }

      </style>

      <table id='reportOptions'></table>
      <div id='reportContents'></div>
      "

    $("#reportOptions").append @formFilterTemplate(
      id: "start"
      label: "Start Date"
      form: "<input id='start' class='date' type='text' value='#{@startDate}'/>"
    )

    $("#reportOptions").append @formFilterTemplate(
      id: "end"
      label: "End Date"
      form: "<input id='end' class='date' type='text' value='#{@endDate}'/>"
    )

   
    selectedLocations = {}
    _.each @locationTypes, (locationType) ->
      selectedLocations[locationType] = this[locationType]

    _.each @locationTypes, (locationType,index) =>

      $("#reportOptions").append @formFilterTemplate(
        type: "location"
        id: locationType
        label: locationType.capitalize()
        form: "
          <select data-role='selector' id='#{locationType}'>
            #{
              locationSelectedOneLevelHigher = selectedLocations[@locationTypes[index-1]]
              _.map( ["ALL"].concat(@hierarchyOptions(locationType,locationSelectedOneLevelHigher)), (hierarchyOption) ->
                "<option #{"selected='true'" if hierarchyOption is selectedLocations[locationType]}>#{hierarchyOption}</option>"
              ).join("")
            }
          </select>
        "
      )

    @hideSublocations()


    $("#reportOptions").append @formFilterTemplate(
      id: "report-type"
      label: "Report Type"
      form: "
      <select data-role='selector' id='report-type'>
        #{
          _.map(["dashboard","locations","spreadsheet","summarytables","analysis","alerts", "weeklySummary","periodSummary","incidenceGraph"], (type) =>
            "<option #{"selected='true'" if type is @reportType}>#{type}</option>"
          ).join("")
        }
      </select>
      "
    )

    this[@reportType]()

    $('div[data-role=fieldcontain]').fieldcontain()
    $('select[data-role=selector]').selectmenu()
    $('input.date').datebox
      mode: "calbox"
      dateFormat: "%Y-%m-%d"


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
        <tr id='row-#{options.id}' class='#{options.type}'>
          <td>
            <label style='display:inline' for='#{options.id}'>#{options.label}</label> 
          </td>
          <td style='width:150%'>
            #{options.form}
          </td>
        </tr>
    "

  getCases: (options) =>
    reports = new Reports()
    reports.getCases
      startDate: @startDate
      endDate: @endDate
      success: options.success
      mostSpecificLocation: @mostSpecificLocationSelected()


  alerts: ->

    alerts_to_check = "system_errors, not_followed_up, unknown_districts".split(/, */)
    $("#reportContents").html "
      <h2>Alerts</h2>
      <div id='alerts_status' style='padding-bottom:20px;font-size:150%'>
        <h2>Checking for system alerts:#{alerts_to_check.join(", ")}</h2>
    </div>
      <div id='alerts'>
        #{
          _.map(alerts_to_check, (alert) -> "<div id='#{alert}'><br/></div>").join("")
        }
      </div>
    "

    alerts = false

    console.log alerts_to_check.length
    # Don't call this until all alert checks are complete
    afterFinished = _.after(alerts_to_check.length, ->
      if alerts
        $("#alerts_status").html("<div id='hasAlerts'>Report finished, alerts found.</div>")
      else
        $("#alerts_status").html("<div id='hasAlerts'>Report finished, no alerts found.</div>")
    )


    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/errorsByDate",
      # Note that these seem reversed due to descending order
      startkey: moment().format("YYYY-MM-DD")
      endkey: moment().subtract('days',1).format("YYYY-MM-DD")
      descending: true
      include_docs: true
      success: (result) ->
        errorsByType = {}
        _.chain(result.rows)
          .pluck("doc")
          .each (error) ->
            if errorsByType[error.message]?
              errorsByType[error.message].count++
            else
              errorsByType[error.message]= {}
              errorsByType[error.message].count = 0
              errorsByType[error.message]["Most Recent"] = error.datetime
              errorsByType[error.message]["Source"] = error.source

            errorsByType[error.message]["Most Recent"] = error.datetime if errorsByType[error.message]["Most Recent"] < error.datetime

        if _(errorsByType).isEmpty()
          $("#system_errors").append "No system errors"
        else
          alerts = true

          $("#system_errors").append "
            The following system errors have occurred in the last 2 days:
            <table style='border:1px solid black' class='system-errors'>
              <thead>
                <tr>
                  <th>Time of most recent error</th>
                  <th>Message</th>
                  <th>Number of errors of this type in last 24 hours</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(errorsByType, (errorData, errorMessage) ->
                    "
                      <tr>
                        <td>#{errorData["Most Recent"]}</td>
                        <td>#{errorMessage}</td>
                        <td>#{errorData.count}</td>
                        <td>#{errorData["Source"]}</td>
                      </tr>
                    "
                  ).join("")
                }
              </tbody>
            </table>
          "
        afterFinished()
        console.log "ASDAS"

    reports = new Reports()
    reports.casesAggregatedForAnalysis
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (cases) ->

        if cases.followupsByDistrict["ALL"].length is 0
          $("#not_followed_up").append "All cases between #{@startDate()} and #{@endDate()} have been followed up within two days."
        else
          alerts = true

          $("#not_followed_up").append "
            The following districts have USSD Notifications that have not been followed up after two days. Recommendation call the DMSO:
            <table  style='border:1px solid black' class='alerts'>
              <thead>
                <tr>
                  <th>Number of cases</th>
                  <th>District</th>
                  <th>Officer</th>
                  <th>Phone number</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(cases.followupsByDistrict, (result,district) ->
                    return "" if district is "ALL" or district is "UNKNOWN"

                    casesNotFollowedUp = result.casesNotFollowedUp.length
                    return if casesNotFollowedUp is 0

                    user = Users.where(
                      district: district
                    )
                    user = user[0] if user.length

                    "
                      <tr>
                        <td>#{casesNotFollowedUp}</td>
                        <td>#{district.titleize()}</td>
                        <td>#{user.get? "name"}</td>
                        <td>#{user.username?()}</td>
                      </tr>
                    "
                  ).join("")
                }
              </tbody>
            </table>
          "
        afterFinished()
        console.log "ASDAS"

        if cases.followupsByDistrict["UNKNOWN"].length is 0
          $("#unknown_districts").append "No unknown districts reported"
        else
          alerts = true

          $("#unknown_districts").append "
            The following notifications are for unknown districts. Please contact an administrator if you can identify the correct districts.
            <table style='border:1px solid black' class='unknown-districts'>
              <thead>
                <tr>
                  <th>Health facility</th>
                  <th>Shehia</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(cases.followupsByDistrict["UNKNOWN"].casesNotFollowedUp, (caseNotFollowedUp) ->
                    return unless caseNotFollowedUp["USSD Notification"]
                    "
                      <tr>
                        <td>#{caseNotFollowedUp["USSD Notification"].hf.titleize()}</td>
                        <td>#{caseNotFollowedUp["USSD Notification"].shehia.titleize()}</td>
                      </tr>
                    "
                  ).join("")
                }
              </tbody>
            </table>
          "
        afterFinished()

  locations: ->

    $("#reportOptions").append @formFilterTemplate(
      id: "cluster"
      label: "Cluster"
      form: "
        <select name='cluster' id='cluster' data-role='slider'>
          <option value='off'>Off</option>
          <option value='on' #{if @cluster is "on" then "selected='true'" else ''}'>On</option>
        </select> 
      "
    )

    $("#reportContents").html "
      Use + - buttons to zoom map. Click and drag to reposition the map. Circles with a darker have multiple cases. Red cases show households with additional positive malaria cases.<br/>
      <div id='map' style='width:100%; height:600px;'></div>
    "

    $("#cluster").slider()

    @getCases
      # map notificatoin location too
      success: (results) =>

        locations = _.compact(_.map results, (caseResult) ->
          if caseResult.Household?["HouseholdLocation-latitude"]
            return {
              MalariaCaseID: caseResult.caseID
              latitude: caseResult.Household?["HouseholdLocation-latitude"]
              longitude: caseResult.Household?["HouseholdLocation-longitude"]
              hasAdditionalPositiveCasesAtHousehold: caseResult.hasAdditionalPositiveCasesAtHousehold()
              date: caseResult.Household?.lastModifiedAt
            }
        )

        if locations.length is 0
          $("#map").html "
            <h2>No location information for the range specified.</h2>
          "
          return

        latitudeSum = _.reduce locations, (memo,location) ->
          memo + Number(location.latitude)
        , 0

        longitudeSum = _.reduce locations, (memo,location) ->
          memo + Number(location.longitude)
        , 0

        # Use the average to center the map
        map = new L.Map('map', {
          center: new L.LatLng(
            latitudeSum/locations.length,
            longitudeSum/locations.length
          )
          zoom: 9
        })



#        map.addLayer(
#          new L.TileLayer(
#            'http://{s}.tile.cloudmade.com/4eb20961f7db4d93b9280e8df9b33d3f/997/256/{z}/{x}/{y}.png',
#            {maxZoom: 18}
#          )
#        )
#


        osm = new L.TileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png')
#        bing = new L.BingLayer("Anqm0F_JjIZvT0P3abS6KONpaBaKuTnITRrnYuiJCE0WOhH6ZbE4DzeT6brvKVR5")
        cloudmade = new L.TileLayer(
            'http://{s}.tile.cloudmade.com/4eb20961f7db4d93b9280e8df9b33d3f/997/256/{z}/{x}/{y}.png',
            {maxZoom: 18}
          )
        map.addLayer(osm)
        #map.addControl(new L.Control.Layers({'OSM':osm, "Cloudmade":cloudmade }, {}))
        map.addControl(new L.Control.Layers({'OSM':osm, "Cloudmade":cloudmade, "Google": new L.Google('SATELLITE') }, {}))
        #map.addControl(new L.Control.Layers({'OSM':osm, "Cloumade":cloudmade, "Bing":bing}, {}))

        L.Icon.Default.imagePath = 'js-libraries/Leaflet/images'
        
        if @cluster is "on"
          clusterGroup = new L.MarkerClusterGroup()
          _.each locations, (location) =>
            L.marker([location.latitude, location.longitude])
              .addTo(clusterGroup)
              .bindPopup "#{location.date}: <a href='#show/case/#{location.MalariaCaseID}'>#{location.MalariaCaseID}</a>"
          map.addLayer(clusterGroup)
        else
          _.each locations, (location) =>
            L.circleMarker([location.latitude, location.longitude],
              "fillColor": if location.hasAdditionalPositiveCasesAtHousehold then "red" else ""
              )
              .addTo(map)
              .bindPopup "
                 #{location.date}: <a href='#show/case/#{location.MalariaCaseID}'>#{location.MalariaCaseID}</a>
               "

  spreadsheet: ->

    $("#reportContents").html "
      <a href='http://spreadsheet.zmcp.org/spreadsheet/#{@startDate}/#{@endDate}'>Download spreadsheet for #{@startDate} to #{@endDate}</a>
    "
    $("a#csv").button()

  results: ->
    $("#reportContents").html "
      <table id='results' class='tablesorter'>
        <thead>
          <tr>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    "

    @getCases
      success: (cases) =>
        fields = "MalariaCaseID,LastModifiedAt,Questions".split(",")

        tableData = _.chain(cases)
        .sortBy  (caseResult) ->
          caseResult.LastModifiedAt()
        .value()
        .reverse()
        .map (caseResult) ->
          _.map fields, (field) ->
            caseResult[field]()

        $("table#results thead tr").append "
          #{ _.map(fields, (field) ->
            "<th>#{field}</th>"
          ).join("")
          }
        "

        $("table#results tbody").append _.map(tableData, (row) ->  "
          <tr>
            #{_.map(row, (element,index) -> "
              <td>#{
                if index is 0
                  "<a href='#show/case/#{element}'>#{element}</a>"
                else
                  element
              }</td>
            ").join("")
            }
          </tr>
        ").join("")

  getFieldListSelector: (resultCollection, selectorId) ->

        fields = _.chain(resultCollection.toJSON())
        .map (result) ->
          _.keys(result)
        .flatten()
        .uniq()
        .sort()
        .value()

        fields = _.without(fields, "_id", "_rev")
    
        return "
          <br/>
          Choose a field to summarize:<br/>
          <select data-role='selector' class='summarySelector' id='#{selectorId}'>
            <option></option>
            #{
              _.map(fields, (field) ->
                "<option id='#{field}'>#{field}</option>"
              ).join("")
            }
          </select>
        "

  summarytables: ->
    Coconut.resultCollection.fetch
      include_docs: true
      success: =>

        # TODO don't use Coconut.resultCollection - too BIG!!
        $("#reportContents").html @getFieldListSelector(Coconut.resultCollection, "summaryField1")
        $('#summaryField1').selectmenu()
        if @summaryField1?
          $('#summaryField1').val @summaryField1
          $('#summaryField1').selectmenu("refresh")
          @summarize @summaryField1

  summarySelectorChanged: (event) ->
    @summarize $(event.target).find("option:selected").text()
    @update()

  summarize: (field) ->

    @getCases
      success: (cases) =>
        results = {}

        _.each cases, (caseData) ->

          _.each caseData.toJSON(), (value,key) ->
            valuesToCheck = []
            if key is "Household Members"
              valuesToCheck = value
            else
              valuesToCheck.push value

            _.each valuesToCheck, (value,key) ->
              if value[field]?
                unless results[value[field]]?
                  results[value[field]] = {}
                  results[value[field]]["sums"] = 0
                  results[value[field]]["resultData"] = []
                results[value[field]]["sums"] += 1
                results[value[field]]["resultData"].push
                  caseID: caseData.caseID
                  resultID: value._id
                
        @$el.append  "<div id='summaryTables'></div>" unless $("#summaryTables").length is 1

        $("#summaryTables").html  "
          <h2>#{field}</h2>
          <table id='summaryTable' class='tablesorter'>
            <thead>
              <tr>
                <th>Value</th>
                <th>Total</th>
                <th class='cases'>Cases</th>
              </tr>
            </thead>
            <tbody>
              #{
                _.map( results, (aggregates,value) ->
                  "
                  <tr data-row-value='#{value}'>
                    <td>#{value}</td>
                    <td>
                      <button class='toggleDisaggregation'>#{aggregates["sums"]}</button>
                    </td>
                    <td class='cases'>
                      #{
                        _.map(aggregates.resultData, (resultData) ->
                          "<a data-result-id='#{resultData.resultID}' data-case-id='#{resultData.caseID}' data-row-value='#{value}' class='case' href='#show/case/#{resultData.caseID}/#{resultData.resultID}'>#{resultData.caseID}</a>"
                        ).join("")
                      }
                    </td>
                  </tr>
                  "
                ).join("")
              }
            </tbody>
          </table>
          <h3>
          Disaggregate summary based on another variable
          </h3>
        "
        $("#summaryTables").append $("#summaryField1").clone().attr("id", "summaryField2")
        $("#summaryField2").selectmenu()

        $("button").button()
        $("a").button()

        _.each $('table tr'), (row, index) ->
          $(row).addClass("odd") if index%2 is 1


  toggleDisaggregation: (event) ->
    $(event.target).parents("td").siblings(".cases").toggle()

  toggleDisaggregationSameCell: (event) ->
    $(event.target).siblings(".cases").toggle()

  summarySelector2Changed: (event) ->
    @disaggregateSummary $(event.target).find("option:selected").text()

  disaggregateSummary:(field) ->
    data = {}
    disaggregatedSummaryTable = $("#summaryTable").clone().attr("id","disaggregatedSummaryTable")
    cases  = disaggregatedSummaryTable.find("a.case")
    _.each cases, (caseElement) ->
      caseElement = $(caseElement)
      rowValue = caseElement.attr("data-row-value")
      data[rowValue] = {} unless data[rowValue]
      resultID =  caseElement.attr("data-result-id")
      result = new Result
        _id: resultID
      result.fetch
        success: ->
          fieldValue = result.get field
          if fieldValue?
            unless data[rowValue][fieldValue]
              data[rowValue][fieldValue] = 0
            data[rowValue][fieldValue] += 1
            afterLookups()
          else
            caseID =  caseElement.attr("data-case-id")
            caseData = new Case
              caseID: caseID
            caseData.fetch
              success: ->
                fieldValue = caseData.flatten()[field]
                unless data[rowValue][fieldValue]
                  data[rowValue][fieldValue] = 0
                data[rowValue][fieldValue] += 1
                afterLookups()
    afterLookups = _.after cases.length, ->
      columns = _.uniq(_.flatten(_.map(data, (row) ->
        _.keys row
      )).sort())
      disaggregatedSummaryTable.find("thead tr").append(_.map(columns, (column)->
          "<th>#{column}</th>"
        ).join("")
      )
      _.each data, (value, rowValue) ->
        row = disaggregatedSummaryTable.find("tbody tr[data-row-value='#{rowValue}']")
        _.each columns, (column) ->
          if value[column]
            row.append "<td>#{value[column]}</td>"
          else
            row.append "<td>0</td>"

      $("#summaryTables").append disaggregatedSummaryTable
  

  createTable: (headerValues, rows) ->
   "
      <table class='tablesorter'>
        <thead>
          <tr>
            #{
              _.map(headerValues, (header) ->
                "<th>#{header}</th>"
              ).join("")
            }
          </tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
    "

  incidenceGraph: ->
    $("#reportContents").html "<div id='analysis'></div>"

    $("#analysis").append "
      <style>
      #chart_container {
        position: relative;
        font-family: Arial, Helvetica, sans-serif;
      }
      #chart {
        position: relative;
        left: 40px;
      }
      #y_axis {
        position: absolute;
        top: 0;
        bottom: 0;
        width: 40px;
      }
      </style>
      <div id='chart_container'>
        <div id='y_axis'></div>
        <div id='chart'></div>
      </div>
    "
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/positiveCases",
      startkey: "2012"
      include_docs: false
      success: (result) ->
        casesPerAggregationPeriod = {}

        _.each result.rows, (row) ->
          date = moment(row.key.substr(0,10))
          if row.key.substr(0,2) is "20" and date?.isValid() and date > moment.utc("2012-07-01") and date < new moment()
            aggregationKey = date.unix()
            casesPerAggregationPeriod[aggregationKey] = 0 unless casesPerAggregationPeriod[aggregationKey]
            casesPerAggregationPeriod[aggregationKey] += 1
        dataForGraph = _.map casesPerAggregationPeriod, (numberOfCases, date) ->
          x: parseInt(date)
          y: numberOfCases
      
        ###
        This didn't work -  from http://stackoverflow.com/questions/15791907/how-do-i-get-rickshaw-to-aggregate-data-into-weeks-instead-of-days
        aggregated = d3.nest()
        .key (d) ->
          (new Date(+d.x * 1000)).getMonth()
        .rollup (d) ->
          d3.sum(d, (e) -> return +e.y)
        .entries(dataForGraph)
        .map (d) ->
          {x: +d.key, y: d.values}
        ###
  
        graph = new Rickshaw.Graph
          element: document.querySelector("#chart"),
          width: 580,
          height: 250,
          series: [
            color: 'steelblue',
            data: dataForGraph
          ]

        x_axis = new Rickshaw.Graph.Axis.Time
          graph: graph

        y_axis = new Rickshaw.Graph.Axis.Y
          graph: graph,
          orientation: 'left',
          tickFormat: Rickshaw.Fixtures.Number.formatKMBT,
          element: document.getElementById('y_axis'),

        graph.render()

  weeklySummary: (options = {}) ->
    #Last Monday (1) to Sunday (0 + 7)
    currentOptions = _.clone @reportOptions
    currentOptions.startDate = moment().day(1).format(Coconut.config.get "date_format")
    currentOptions.endDate = moment().day(0+7).format(Coconut.config.get "date_format")

    #previous Monday to Sunday
    previousOptions = _.clone @reportOptions
    previousOptions.startDate = moment().day(1-7).format(Coconut.config.get "date_format")
    previousOptions.endDate = moment().day(0+7-7).format(Coconut.config.get "date_format")

    previousPreviousOptions= _.clone @reportOptions
    previousPreviousOptions.startDate = moment().day(1-7-7).format(Coconut.config.get "date_format")
    previousPreviousOptions.endDate = moment().day(0+7-7-7).format(Coconut.config.get "date_format")

    previousPreviousPreviousOptions= _.clone @reportOptions
    previousPreviousPreviousOptions.startDate = moment().day(1-7-7-7).format(Coconut.config.get "date_format")
    previousPreviousPreviousOptions.endDate = moment().day(0+7-7-7-7).format(Coconut.config.get "date_format")

    options.optionsArray = [previousPreviousPreviousOptions, previousPreviousOptions, previousOptions, currentOptions]
    $("#row-start").hide()
    $("#row-end").hide()
    @periodSummary(options)


  periodSummary: (options = {}) ->
    district = options.district || "ALL"

    # Cases that have NOT been followed up
    # # household interviews < X
    # # of new cases < X
    # increase in cases from MCN > X
    

    $("#reportContents").html "
        <style>
          .data{
            display:none
          }
          table.tablesorter tbody td.trend{
            vertical-align: middle;
          }
          .period-2.trend i{
            font-size:75%
          }
        </style>
        <div id='messages'></div>
        <div id='alerts'>
          <h2>Loading Data Summary...</h2>
        </div>
      "
      
    @reportOptions.startDate = @reportOptions.startDate || moment(new Date).subtract('days',7).format("YYYY-MM-DD")
    @reportOptions.endDate = @reportOptions.endDate || moment(new Date).format("YYYY-MM-DD")

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/byCollection",
      # Note that these seem reversed due to descending order
      key: "help"
      include_docs: true
      success: (result) =>
        messages = _(result.rows).chain().map( (data) =>
          return unless moment(@reportOptions.startDate).isBefore(data.value.date) and moment(@reportOptions.endDate).isAfter(data.value.date)
          "#{data.value.date}: #{data.value.text}<br/>"
        ).compact().value().join("")
        if messages isnt "" then $("#messages").html "
          <h2>Help Messages</h2>
          #{messages}
        "

    if options.optionsArray
      console.log options.optionsArray
      optionsArray = options.optionsArray
    else
      amountOfTime = moment(@reportOptions.endDate).diff(moment(@reportOptions.startDate))

      previousOptions = _.clone @reportOptions
      previousOptions.startDate = moment(@reportOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get "date_format")
      previousOptions.endDate = @reportOptions.startDate

      previousPreviousOptions= _.clone @reportOptions
      previousPreviousOptions.startDate = moment(previousOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get "date_format")
      previousPreviousOptions.endDate = previousOptions.startDate

      previousPreviousPreviousOptions= _.clone @reportOptions
      previousPreviousPreviousOptions.startDate = moment(previousPreviousOptions.startDate).subtract("milliseconds", amountOfTime).format(Coconut.config.get "date_format")
      previousPreviousPreviousOptions.endDate = previousPreviousOptions.startDate
      optionsArray = [previousPreviousPreviousOptions, previousPreviousOptions, previousOptions, @reportOptions]

    results = []

    dataValue = (data) =>
      if data.disaggregated?
        data.disaggregated.length
      else if data.percent?
        @formattedPercent(data.percent)
      else if data.text?
        data.text

    renderDataElement = (data) =>
      if data.disaggregated?
        output = @createDisaggregatableCaseGroup(data.disaggregated.length,data.disaggregated)
        if data.appendPercent?
          output += " (#{@formattedPercent(data.appendPercent)})"
        output
      else if data.percent?
        @formattedPercent(data.percent)
      else if data.text?
        data.text

    renderTable = _.after optionsArray.length, =>
      $("#alerts").html "
        <h2>Data Summary</h2>
        <table id='alertsTable' class='tablesorter'>
          <tbody>
            #{
              index = 0
              _(results[0]).map( (firstResult) =>
                "
                <tr class='#{if index%2 is 0 then "odd" else "even"}'>
                  <td>#{firstResult.title}</td>
                  #{
                    period = results.length
                    sum = 0
                    element = _.map( results, (result) ->
                      sum += parseInt(dataValue(result[index]))
                      "
                        <td class='period-#{period-=1} trend'></td>
                        <td class='period-#{period} data'>#{renderDataElement(result[index])}</td>
                        #{
                          if period is 0
                            "<td class='average-for-previous-periods'>#{sum/results.length}</td>"
                          else  ""
                        }
                      "
                    ).join("")
                    index+=1
                    element
                  }
                </tr>
                "
              ).join("")
            }
          </tbody>
        </table>
        <button class='toggle-trend-data'>Show trend data</button>
      "

      extractNumber = (element) ->
        result = parseInt(element.text())
        if isNaN(result)
          parseInt(element.find("button").text())
        else
          result

      # Analyze the trends
      _(results.length-1).times (period) ->
        _.each $(".period-#{period}.data"), (dataElement) ->
          dataElement = $(dataElement)
          current = extractNumber(dataElement)
          previous = extractNumber(dataElement.prev().prev())
          dataElement.prev().html if current is previous then "-" else if current > previous then "<span class='up-arrow'>&uarr;</span>" else "<span class='down-arrow'>&darr;</span>"
          
      _.each $(".period-0.trend"), (period0Trend) ->
        period0Trend = $(period0Trend)
        if period0Trend.prev().prev().find("span").attr("class") is period0Trend.find("span").attr("class")
          period0Trend.find("span").attr "style", "color:red"

      #
      #Clean up the table
      # 
      $(".period-0.data").show()
      $(".period-#{results.length-1}.trend").hide()
      $(".period-1.trend").attr "style", "font-size:75%"
      $(".trend")
      $("td:contains(Period)").siblings(".trend").find("i").hide()
      $(".period-0.data").show()
      $($(".average-for-previous-periods")[0]).html "Average for previous #{results.length-1} periods"

      swapColumns =  (table, colIndex1, colIndex2) ->
        if !colIndex1 < colIndex2
          t = colIndex1
          colIndex1 = colIndex2
          colIndex2 = t
        
        if table && table.rows && table.insertBefore && colIndex1 != colIndex2
          for row in table.rows
            cell1 = row.cells[colIndex1]
            cell2 = row.cells[colIndex2]
            siblingCell1 = row.cells[Number(colIndex1) + 1]
            row.insertBefore(cell1, cell2)
            row.insertBefore(cell2, siblingCell1)

      swapColumns($("#alertsTable")[0], 8, 9)

      #
      #End of clean up the table
      # 


    reportIndex = 0
    _.each optionsArray, (options) =>
      console.log options
      # This is an ugly hack to use local scope to ensure the result order is correct
      anotherIndex = reportIndex
      reportIndex++

      reports = new Reports()
      reports.casesAggregatedForAnalysis
        startDate: options.startDate
        endDate: options.endDate
        mostSpecificLocation: @mostSpecificLocationSelected()
        success: (data) =>

          results[anotherIndex] = [
            title         : "Period"
            text          :  "#{moment(options.startDate).format("YYYY-MM-DD")} -> #{moment(options.endDate).format("YYYY-MM-DD")}"
          ,
            title         : "No. of cases reported at health facilities"
            disaggregated :  data.followupsByDistrict[district].allCases
          ,
            title         : "No. of cases reported at health facilities followed up"
            disaggregated : data.followupsByDistrict[district].casesFollowedUp
          ,
            title         : "% of cases reported at health facilities followed up"
            percent       : 1 - (data.followupsByDistrict[district].casesFollowedUp.length/data.followupsByDistrict[district].allCases.length)
          ,
            title         : "Total No. of cases (including cases not reported by facilities) followed up"
            disaggregated : data.followupsByDistrict[district].casesFollowedUp
          ,
            title         : "No. of additional household members tested"
            disaggregated : data.passiveCasesByDistrict[district].householdMembers
          ,
            title         : "No. of additional household members tested positive"
            disaggregated : data.passiveCasesByDistrict[district].passiveCases
          ,
            title         : "% of household members tested positive"
            percent       : data.passiveCasesByDistrict[district].passiveCases.length / data.passiveCasesByDistrict[district].householdMembers.length
          ,
            title         : "% increase in cases found using MCN"
            percent       : data.passiveCasesByDistrict[district].passiveCases.length / data.passiveCasesByDistrict[district].indexCases.length
          ,
            title         : "No. of positive cases (index & household) in persons under 5"
            disaggregated : data.agesByDistrict[district].underFive
          ,
            title         : "Percent of positive cases (index & household) in persons under 5"
            percent       : data.agesByDistrict[district].underFive.length / data.totalPositiveCasesByDistrict[district].length
          ,
            title         : "Positive Cases (index & household) with at least a facility followup"
            disaggregated : data.totalPositiveCasesByDistrict[district]
          ,
            title         : "Positive Cases (index & household) that slept under a net night before diagnosis (percent)"
            disaggregated : data.netsAndIRSByDistrict[district].sleptUnderNet
            appendPercent : data.netsAndIRSByDistrict[district].sleptUnderNet.length / data.totalPositiveCasesByDistrict[district].length
          ,
            title         : "Positive Cases from a household that has been sprayed within last #{Coconut.IRSThresholdInMonths} months"
            disaggregated : data.netsAndIRSByDistrict[district].recentIRS
            appendPercent : data.netsAndIRSByDistrict[district].recentIRS.length / data.totalPositiveCasesByDistrict[district].length
          ,
            title         : "Positive Cases (index & household) that traveled within last month (percent)"
            disaggregated : data.travelByDistrict[district].travelReported
            appendPercent : data.travelByDistrict[district].travelReported.length / data.totalPositiveCasesByDistrict[district].length
          ]

          renderTable()

  analysis: ->
    reports = new Reports()
    reports.casesAggregatedForAnalysis
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (data) =>

        $("#reportContents").html "<div id='analysis'><hr/><div style='font-style:italic'>Click on a column heading to sort.</div><hr/></div>"

        headings = [
          "District"
          "Cases"
          "Cases followed up (household visit marked complete)"
          "Cases not followed up"
          "% of cases followed up"
          "Cases missing USSD Notification"
          "Cases missing Case Notification"
        ]

        $("#analysis").append "<h2>Cases Followed Up</h2>"
        $("#analysis").append @createTable headings, "
          #{
            _.map(data.followupsByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.allCases.length,values.allCases)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.casesFollowedUp.length,values.casesFollowedUp)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.casesNotFollowedUp.length,values.casesNotFollowedUp)}</td>
                  <td>#{@formattedPercent(values.casesFollowedUp.length/values.allCases.length)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.missingUssdNotification.length,values.missingUssdNotification)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.missingCaseNotification.length,values.missingCaseNotification)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Household Members</h2>
        "
        $("#analysis").append @createTable "District, No. of cases followed up, No. of additional household members tested, No. of additional household members tested positive, % of household members tested positive, % increase in cases found using MCN".split(/, */), "
          #{
#            console.log (_.pluck data.passiveCasesByDistrict.ALL.householdMembers, "MalariaCaseID").join("\n")
            _.map(data.passiveCasesByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.indexCases.length,values.indexCases)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.householdMembers.length,values.householdMembers)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.passiveCases.length,values.passiveCases)}</td>
                  <td>#{@formattedPercent(values.passiveCases.length / values.householdMembers.length)}</td>
                  <td>#{@formattedPercent(values.passiveCases.length / values.indexCases.length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Age: <small>Includes index cases followed up and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, <5, 5<15, 15<25, >=25, Unknown, Total, %<5, %5<15, %15<25, %>=25, Unknown".split(/, */), "
          #{
            _.map(data.agesByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableDocGroup(values.underFive.length,values.underFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fiveToFifteen.length,values.fiveToFifteen)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fifteenToTwentyFive.length,values.fifteenToTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.overTwentyFive.length,values.overTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.unknown.length,values.overTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCasesByDistrict[district].length,data.totalPositiveCasesByDistrict[district])}</td>

                  <td>#{@formattedPercent(values.underFive.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.fiveToFifteen.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.fifteenToTwentyFive.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.overTwentyFive.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.unknown.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Gender: <small>Includes index cases followed up and positive household members<small></h2>
        "
        $("#analysis").append @createTable "District, Male, Female, Unknown, Total, % Male, % Female, % Unknown".split(/, */), "
          #{
            _.map(data.genderByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableDocGroup(values.male.length,values.male)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.female.length,values.female)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.unknown.length,values.unknown)}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCasesByDistrict[district].length,data.totalPositiveCasesByDistrict[district])}</td>

                  <td>#{@formattedPercent(values.male.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.female.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@formattedPercent(values.unknown.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Nets and Spraying: <small>Includes index cases followed up and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, Positive Cases, Positive Cases (index & household) that slept under a net night before diagnosis, %, Positive Cases from a household that has been sprayed within last #{Coconut.IRSThresholdInMonths} months, %".split(/, */), "
          #{
            _.map(data.netsAndIRSByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCasesByDistrict[district].length,data.totalPositiveCasesByDistrict[district])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.sleptUnderNet.length,values.sleptUnderNet)}</td>
                  <td>#{@formattedPercent(values.sleptUnderNet.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.recentIRS.length,values.recentIRS)}</td>
                  <td>#{@formattedPercent(values.recentIRS.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Travel History: <small>Includes index cases followed up and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, Positive Cases, Positive Cases (index & household) that traveled within last month, %".split(/, */), "
          #{
            _.map(data.travelByDistrict, (values,district) =>
              "
                <tr>
                  <td>#{district}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCasesByDistrict[district].length,data.totalPositiveCasesByDistrict[district])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.travelReported.length,values.travelReported)}</td>
                  <td>#{@formattedPercent(values.travelReported.length / data.totalPositiveCasesByDistrict[district].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis table").tablesorter
          widgets: ['zebra']
          sortList: [[0,0]]
          textExtraction: (node) ->
            sortValue = $(node).find(".sort-value").text()
            if sortValue != ""
              sortValue
            else
              if $(node).text() is "--"
                "-1"
              else
                $(node).text()

  formattedPercent: (number) ->
    percent = (number * 100).toFixed(0)
    if isNaN(percent) then "--" else "#{percent}%"

  dashboard: ->
    $("tr.location").hide()
          
    $("#reportContents").html "
      <!--
      Reported/Facility Followup/Household Followup/#Tested/ (Show for Same period last year)
      For completed cases, average time between notification and household followup
      Last seven days
      Last 30 days
      Last 365 days
      Current month
      Current year
      Total
      -->
      <h2>Alerts</h2>
      <div id='alerts'></div>
      <h1>
        Cases
      </h2>
      For the selected period:<br/>
      <table>
        <tr>
          <td>Cases Reported at Facility</td>
          <td id='Cases-Reported-at-Facility'></td>
        </tr>
        <tr>
          <td>Additional People Tested</td>
          <td id='Additional-People-Tested'></td>
        </tr>
        <tr>
          <td>Additional People Tested Positive</td>
          <td id='Additional-People-Tested-Positive'></td>
        </tr>
      </table>
      <br/>

      Click on a button for more details about the case. Pink buttons are for <span style='background-color:pink'> positive malaria results.</span>
      <table class='summary tablesorter'>
        <thead><tr>
        </tr></thead>
        <tbody>
        </tbody>
      </table>
      <style>
        table a, table a:link, table a:visited {color: blue; font-size: 150%}
      </style>
    "

    tableColumns = ["Case ID","Diagnosis Date","Health Facility District","USSD Notification"]
    Coconut.questions.fetch
      success: ->
        tableColumns = tableColumns.concat Coconut.questions.map (question) ->
          question.label()
        _.each tableColumns, (text) ->
          $("table.summary thead tr").append "<th>#{text} (<span id='th-#{text.replace(/\s/,"")}-count'></span>)</th>"

    @getCases
      success: (cases) =>
        _.each cases, (malariaCase) =>

          malariaCase.fetch
            success: =>

              $("table.summary tbody").append "
                <tr id='case-#{malariaCase.caseID}'>
                  <td class='CaseID'>
                    <a href='#show/case/#{malariaCase.caseID}'><button>#{malariaCase.caseID}</button></a>
                  </td>
                  <td class='IndexCaseDiagnosisDate'>
                    #{malariaCase.indexCaseDiagnosisDate()}
                  </td>
                  <td class='HealthFacilityDistrict'>
                    #{
                      if malariaCase["USSD Notification"]?
                        FacilityHierarchy.getDistrict(malariaCase["USSD Notification"].hf)
                      else
                        ""
                    }
                  </td>
                  <td class='USSDNotification'>
                    #{@createDashboardLinkForResult(malariaCase,"USSD Notification", "<img src='images/ussd.png'/>")}
                  </td>
                  <td class='CaseNotification'>
                    #{@createDashboardLinkForResult(malariaCase,"Case Notification","<img src='images/caseNotification.png'/>")}
                  </td>
                  <td class='Facility'>
                    #{@createDashboardLinkForResult(malariaCase,"Facility", "<img src='images/facility.png'/>")}
                  </td>
                  <td class='Household'>
                    #{@createDashboardLinkForResult(malariaCase,"Household", "<img src='images/household.png'/>")}
                  </td>
                  <td class='HouseholdMembers'>
                    #{
                      _.map(malariaCase["Household Members"], (householdMember) =>
                        buttonText = "<img src='images/householdMember.png'/>"
                        unless householdMember.complete?
                          unless householdMember.complete
                            buttonText = buttonText.replace(".png","Incomplete.png")
                        @createCaseLink
                          caseID: malariaCase.caseID
                          docId: householdMember._id
                          buttonClass: if householdMember.MalariaTestResult? and (householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed") then "malaria-positive" else ""
                          buttonText: buttonText
                      ).join("")
                    }
                  </td>
                </tr>
              "
              afterRowsAreInserted()

        afterRowsAreInserted = _.after cases.length, ->
          _.each tableColumns, (text) ->
            columnId = text.replace(/\s/,"")
            $("#th-#{columnId}-count").html $("td.#{columnId} button").length

          $("#Cases-Reported-at-Facility").html $("td.CaseID button").length
          $("#Additional-People-Tested").html $("td.HouseholdMembers button").length
          $("#Additional-People-Tested-Positive").html $("td.HouseholdMembers button.malaria-positive").length

          if $("table.summary tr").length > 1
            $("table.summary").tablesorter
              widgets: ['zebra']
              sortList: [[1,1]]

          districtsWithFollowup = {}
          _.each $("table.summary tr"), (row) ->
              row = $(row)
              if row.find("td.USSDNotification button").length > 0
                if row.find("td.CaseNotification button").length is 0
                  if moment().diff(row.find("td.IndexCaseDiagnosisDate").html(),"days") > 2
                    districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()] = 0 unless districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()]?
                    districtsWithFollowup[row.find("td.HealthFacilityDistrict").html()] += 1
          $("#alerts").append "
          <style>
            #alerts,table.alerts{
              font-size: 80% 
            }

          </style>
          The following districts have USSD Notifications that have not been followed up after two days. Recommendation call the DMSO:
            <table class='alerts'>
              <thead>
                <tr>
                  <th>District</th><th>Number of cases</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(districtsWithFollowup, (numberOfCases,district) -> "
                    <tr>
                      <td>#{district}</td>
                      <td>#{numberOfCases}</td>
                    </tr>
                  ").join("")
                }
              </tbody>
            </table>
          "

  createDashboardLinkForResult: (malariaCase,resultType,buttonText = "") ->
    if malariaCase[resultType]?
      unless malariaCase[resultType].complete?
        unless malariaCase[resultType].complete
          buttonText = buttonText.replace(".png","Incomplete.png") unless resultType is "USSD Notification"
      @createCaseLink
        caseID: malariaCase.caseID
        docId: malariaCase[resultType]._id
        buttonText: buttonText
    else ""

  createCaseLink: (options) ->
    options.buttonText ?= options.caseID
    "<a href='#show/case/#{options.caseID}#{if options.docId? then "/" + options.docId else ""}'><button class='#{options.buttonClass}'>#{options.buttonText}</button></a>"


  createCasesLinks: (cases) ->
    _.map(cases, (malariaCase) =>
      @createCaseLink  caseID: malariaCase.caseID
    ).join("")

  createDisaggregatableCaseGroup: (text,cases) ->
    "
      <button class='sort-value same-cell-disaggregatable'>#{text}</button>
      <div class='cases' style='display:none'>
        #{@createCasesLinks cases}
      </div>
    "

  createDocLinks: (docs) ->
    _.map(docs, (doc) =>
      @createCaseLink
        caseID: doc.MalariaCaseID
        docId: doc._id
    ).join("")

  createDisaggregatableDocGroup: (text,docs) ->
    "
      <button class='sort-value same-cell-disaggregatable'>#{text}</button>
      <div class='cases' style='display:none'>
        #{@createDocLinks docs}
      </div>
    "

