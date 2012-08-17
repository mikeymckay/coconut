class ReportView extends Backbone.View
  initialize: ->
    $("html").append "
      <link href='js-libraries/Leaflet/leaflet.css' type='text/css' rel='stylesheet' />
      <script type='text/javascript' src='js-libraries/Leaflet/leaflet-src.js'></script>

      <!--
      <script src='../lib/leaflet-dist/leaflet-src.js'></script>
      -->
      <link rel='stylesheet' href='js-libraries/Leaflet/MarkerCluster.css' />
      <link rel='stylesheet' href='js-libraries/Leaflet/MarkerCluster.Default.css' />
      <script src='js-libraries/Leaflet/leaflet.markercluster-src.js'></script>
      <script src='http://maps.google.com/maps/api/js?v=3.2&sensor=false'></script>
	    <script src='js-libraries/Leaflet/leaflet-plugins/layer/tile/Bing.js'></script>


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
    "change #cluster": "update"
    "click .toggleDisaggregation": "toggleDisaggregation"

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
    @cluster = options.cluster || "off"

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
          _.map(["dashboard","locations","spreadsheet","summarytables"], (type) =>
            "<option #{"selected='true'" if type is @reportType}>#{type}</option>"
          ).join("")
        }
      </select>
      "
    )


    this[@reportType]()

    $('div[data-role=fieldcontain]').fieldcontain()
    $('select[data-role=selector]').selectmenu()
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
        <tr id='row-#{options.id}' class='#{options.type}'>
          <td>
            <label style='display:inline' for='#{options.id}'>#{options.label}</label> 
          </td>
          <td style='width:150%'>
            #{options.form}
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

    @viewQuery
      # TODO use Cases, map notificatoin location too
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
        bing = new L.BingLayer("Anqm0F_JjIZvT0P3abS6KONpaBaKuTnITRrnYuiJCE0WOhH6ZbE4DzeT6brvKVR5")
        map.addLayer(bing)
        map.addControl(new L.Control.Layers({'OSM':osm, "Bing":bing}, {}))

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
          <select data-role='selector' id='summaryField'>
            <option></option>
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

    $.couch.db(Coconut.config.database_name()).view "zanzibar/caseIDsByDate"
      startkey: moment(@endDate).eod().format(Coconut.config.get "date_format")
      endkey: @startDate
      descending: true
      include_docs: true
      success: (result) =>
          
        caseIDs = _.unique(_.map result.rows, (object) ->
          object.value
        )

        afterRowsAreInserted = _.after caseIDs.length, ->
          _.each tableColumns, (text) ->
            columnId = text.replace(/\s/,"")
            $("#th-#{columnId}-count").html $("td.#{columnId} button").length

          $("#Cases-Reported-at-Facility").html $("td.CaseID button").length
          $("#Additional-People-Tested").html $("td.HouseholdMembers button").length
          $("#Additional-People-Tested-Positive").html $("td.HouseholdMembers button.malaria-positive").length

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

        _.each(caseIDs, (caseID) =>

          malariaCase = new Case
            caseID: caseID

          malariaCase.fetch
            success: =>

              $("table.summary tbody").append "
                <tr id='case-#{caseID}'>
                  <td class='CaseID'>
                    <a href='#show/case/#{caseID}'><button>#{caseID}</button></a>
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
                    #{@createDashboardLinkForResult(malariaCase,"USSD Notification")}
                  </td>
                  <td class='CaseNotification'>
                    #{@createDashboardLinkForResult(malariaCase,"Case Notification")}
                  </td>
                  <td class='Facility'>
                    #{@createDashboardLinkForResult(malariaCase,"Facility")}
                  </td>
                  <td class='Household'>
                    #{@createDashboardLinkForResult(malariaCase,"Household")}
                  </td>
                  <td class='HouseholdMembers'>
                    #{
                      _.map(malariaCase["Household Members"], (householdMember) =>
                        @createDashboardLink
                          caseID: malariaCase.caseID
                          docId: householdMember._id
                          buttonClass: if householdMember.MalariaTestResult? and (householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed") then "malaria-positive" else ""
                          #buttonText: moment(row.doc.lastModifiedAt || row.doc.date, Coconut.config.get "date_format").format("D MMM HH:mm")
                          #buttonText: (row.doc.lastModifiedAt || row.doc.date)
                          buttonText: ""
                      ).join("")
                    }
                  </td>
                </tr>
              "
              afterRowsAreInserted()
        )

  createDashboardLinkForResult: (malariaCase,resultType) ->
    if malariaCase[resultType]?
      @createDashboardLink
        caseID: malariaCase.caseID
        docId: malariaCase[resultType]._id
        buttonText: ""
    else ""


  createDashboardLink: (options) ->
      "<a href='#show/case/#{options.caseID}/#{options.docId}'><button class='#{options.buttonClass}'>#{options.buttonText}</button></a>"
