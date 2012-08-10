class ReportView extends Backbone.View
  initialize: ->
    $("html").append "
      <link href='js-libraries/Leaflet/leaflet.css' type='text/css' rel='stylesheet' />
      <script type='text/javascript' src='js-libraries/Leaflet/leaflet.js'></script>
      <style>
        .cases{
          display: none;
        }
      </style>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"
    "change #summaryField": "summarize"
    "click .toggleDisaggregation": "toggleDisaggregation"

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
    @locationTypes = "region, district, constituan, shehia".split(/, /)

    _.each (@locationTypes), (option) ->
      if options[option] is undefined
        this[option] = "ALL"
      else
        this[option] = unescape(options[option])
    @reportType = options.reportType || "dashboard"
    @startDate = options.startDate || moment(new Date).subtract('days',7).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")

    @$el.html "
      <style>
        table.results th.header, table.results td{
          font-size:150%;
        }

      </style>

      <table id='reportOptions'></table>
      <div id='reportContents'></div>
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

   
    selectedLocations = {}
    _.each @locationTypes, (locationType) ->
      selectedLocations[locationType] = this[locationType]

    _.each @locationTypes, (locationType,index) =>

      $("#reportOptions").append @formFilterTemplate(
        type: "location"
        id: locationType
        label: locationType.capitalize()
        form: "
          <select id='#{locationType}'>
            #{
              locationSelectedOneLevelHigher = selectedLocations[@locationTypes[index-1]]
              _.map( ["ALL"].concat(@hierarchyOptions(locationType,locationSelectedOneLevelHigher)), (hierarchyOption) ->
                "<option #{"selected='true'" if hierarchyOption is selectedLocations[locationType]}>#{hierarchyOption}</option>"
              ).join("")
            }
          </select>
        "
      )


    $("#reportOptions").append @formFilterTemplate(
      id: "report-type"
      label: "Report Type"
      form: "
      <select id='report-type'>
        #{
          _.map(["dashboard","locations","spreadsheet","summarytables"], (type) =>
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
        <tr class='#{options.type}'>
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
    $.couch.db(Coconut.config.database_name()).view "zanzibar/caseByLastModified",
      descending: true
      include_docs: true
      # Note that these seem reversed due to descending order
      startkey: moment(@endDate).eod().format(Coconut.config.get "date_format")
      endkey: @startDate
      success: (result) =>

        resultHash = {}
        _.each result.rows, (caseResult) ->
          resultHash[caseResult.doc["MalariaCaseID"]] = [] unless resultHash[caseResult.doc["MalariaCaseID"]]
          resultHash[caseResult.doc["MalariaCaseID"]].push new Result(caseResult.doc)

        cases = _.chain(resultHash)
        .map (results,caseID) =>
          malariaCase = new Case
            results: results
          mostSpecificLocationSelected = @mostSpecificLocationSelected()
          if mostSpecificLocationSelected.name is "ALL" or malariaCase.withinLocation(mostSpecificLocationSelected)
            return malariaCase
        .compact()
        .value()

        options.success(cases)


  locations: ->
    $("#reportContents").html "
      <div id='map' style='width:100%; height:600px;'></div>
    "

    @viewQuery
      # TODO use Cases, map notificatoin location too
      success: (results) =>

        locations = _.compact(_.map results, (caseResult) ->
          if caseResult.Household?["HouseholdLocation-latitude"]
            return {
              MalariaCaseID: caseResult.caseId
              latitude: caseResult.Household?["HouseholdLocation-latitude"]
              longitude: caseResult.Household?["HouseholdLocation-longitude"]
            }
        )

        if locations.length is 0
          $("#map").html "
            <h2>No location information for the range specified.</h2>
          "
          return

        map = new L.Map('map', {
          center: new L.LatLng(
            locations[0]?.latitude,
            locations[0]?.longitude
          )
          zoom: 9
        })

        map.addLayer(
          new L.TileLayer(
            'http://{s}.tile.cloudmade.com/4eb20961f7db4d93b9280e8df9b33d3f/997/256/{z}/{x}/{y}.png',
            {maxZoom: 18}
          )
        )

        _.each locations, (location) =>
          map.addLayer(
            new L.CircleMarker(
              new L.LatLng(location.latitude, location.longitude)
            )
          )


  spreadsheet: ->
    @viewQuery
      success: (cases) =>

        fields = {}
        csv = {}
        allCasesFlattened = _.map cases, (malariaCase) ->

          malariaCaseFlattened = malariaCase.flatten()
          _.each _.keys(malariaCaseFlattened), (field) ->
            fields[field] = true
          return malariaCaseFlattened

        csvHeaders = (_.keys(fields)).join(",")

        csvData = _.map(allCasesFlattened, (malariaCaseFlattened) ->
          _.map(fields, (value,key) ->
            csv[key] = [] unless csv[key]
            csv[key].push malariaCaseFlattened[key] || null
            return malariaCaseFlattened[key] || null
          ).join(",")
        ).join("\n")

        $("#reportContents").html "
          <a id='csv' href='data:text/octet-stream;base64,#{Base64.encode(csvHeaders + "\n" + csvData)}' download='#{@startDate+"-"+@endDate}.csv'>Download spreadsheet</a>
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

    @viewQuery
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

  summarytables: ->
    Coconut.resultCollection.fetch
      include_docs: true
      success: =>

        fields = _.chain(Coconut.resultCollection.toJSON())
        .map (result) ->
          _.keys(result)
        .flatten()
        .uniq()
        .sort()
        .value()

        fields = _.without(fields, "_id", "_rev")
    
        $("#reportContents").html "
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
        $('#summaryField').selectmenu()


  summarize: ->
    field = $('#summaryField option:selected').text()

    @viewQuery
      success: (cases) =>
        results = {}

        #Refactor me PLEASE

        _.each cases, (caseData) ->
          _.each caseData.toJSON(), (value,key) ->
            if key is "Household Members"
              _.each value, (value,key) ->
                if value[field]?
                  if results[value[field]]?
                    results[value[field]]["sums"] += 1
                    results[value[field]]["caseIDs"].push caseData.caseID
                  else
                    results[value[field]] = {}
                    results[value[field]]["sums"] = 1
                    results[value[field]]["caseIDs"] = []
                    results[value[field]]["caseIDs"].push caseData.caseID

            else if value[field]?
              if results[value[field]]?
                results[value[field]]["sums"] += 1
                results[value[field]]["caseIDs"].push caseData.caseID
              else
                results[value[field]] = {}
                results[value[field]]["sums"] = 1
                results[value[field]]["caseIDs"] = []
                results[value[field]]["caseIDs"].push caseData.caseID

                
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
                  <tr>
                    <td>#{value}</td>
                    <td>
                      <button class='toggleDisaggregation'>#{aggregates["sums"]}</button>
                    </td>
                    <td class='cases'>
                      #{
                        _.map(aggregates["caseIDs"], (caseID) ->
                          "<a href='#show/case/#{caseID}'>#{caseID}</a>"
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


  toggleDisaggregation: (event) ->
    $(event.target).parents("td").siblings(".cases").toggle()

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
      <h1>
        Cases
      </h2>
      The dates for each case result are shown below. Pink buttons are for <span style='background-color:pink'> positive malaria results.</span>
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

    tableColumns = ["Case ID","Health Facility District","MEEDS Notification"]
    Coconut.questions.fetch
      success: ->
        tableColumns = tableColumns.concat Coconut.questions.map (question) ->
          question.label()
        _.each tableColumns, (text) ->
          $("table.summary thead tr").append "<th>#{text}</th>"

    $.couch.db(Coconut.config.database_name()).view "zanzibar/caseIDsByDate"
      startkey: moment(@endDate).eod().format(Coconut.config.get "date_format")
      endkey: @startDate
      descending: true
      include_docs: true
      success: (result) ->
          
        caseIds = _.unique(_.map result.rows, (object) ->
          object.value
        )

        afterRowsAreInserted = _.after caseIds.length, ->
          $("table.summary").tablesorter
            widgets: ['zebra']
            sortList: [[2,1]]

        _.each caseIds, (caseId) ->
          $.couch.db(Coconut.config.database_name()).view "zanzibar/cases"
            key: caseId
            include_docs: true
            success: (result) ->
              tableRow = $("<tr id='case-#{caseId}'>
                #{_.map(tableColumns, (type) ->
                  "<td class='#{type.replace(/\ /g,'')}'></td>"
                  ).join("")
                }
                </tr>")
              tableRow.find("td.CaseID").html "<a href='#show/case/#{caseId}'><button>#{caseId}</button></a>"
              _.each result.rows, (row) ->
                if row.doc.question?
                  if row.doc.question is "Household Members" and (row.doc.MalariaTestResult is "PF" or row.doc.MalariaTestResult is "Mixed")
                    contents = "<a href='#show/case/#{caseId}/#{row.doc._id}'><button style='background-color:pink'>#{row.doc.lastModifiedAt}</button></a>"
                  else
                    contents = "<a href='#show/case/#{caseId}/#{row.doc._id}'><button>#{row.doc.lastModifiedAt}</button></a>"
                  tableRow.find("td.#{row.doc.question.replace(/\ /g,'')}").append(contents + "<br/>")
                else if row.doc.caseid?
                  tableRow.find("td.HealthFacilityDistrict").append(FacilityHierarchy.getDistrict(row.doc.hf))
                  tableRow.find("td.MEEDSNotification").html "<a href='#show/case/#{caseId}/#{row.doc._id}'><button>#{row.doc.date}</button></a>"
                $("table.summary tbody").append tableRow
              afterRowsAreInserted()
