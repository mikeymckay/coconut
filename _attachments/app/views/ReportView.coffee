class ReportView extends Backbone.View
  initialize: ->
    $("html").append "

      <style>
        .cases{
          display: none;
        }
      </style>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"
    "change #summaryField1": "summarySelectorChanged"
    "change #summaryField2": "summarySelector2Changed"
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
      summaryField1: $("#summaryField1").val()

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

  getCases: (options) ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/caseIDsByDate",
      # Note that these seem reversed due to descending order
      startkey: moment(@endDate).eod().format(Coconut.config.get "date_format")
      endkey: @startDate
      descending: true
      include_docs: false
      success: (result) =>

        caseIDs = _.unique(_.pluck result.rows, "value")

        cases = _.map caseIDs, (caseID) =>
          malariaCase = new Case
            caseID: caseID
          malariaCase.fetch
            success: =>
              afterAllCasesDownloaded()
          return malariaCase

        afterAllCasesDownloaded = _.after caseIDs.length, =>
          cases = _.chain(cases)
          .map (malariaCase) =>
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
    @getCases
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
      console.log data
      columns = _.uniq(_.flatten(_.map(data, (row) ->
        _.keys row
      )).sort())
      console.log columns
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
                        @createDashboardLink
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
      @createDashboardLink
        caseID: malariaCase.caseID
        docId: malariaCase[resultType]._id
        buttonText: buttonText
    else ""


  createDashboardLink: (options) ->
      "<a href='#show/case/#{options.caseID}/#{options.docId}'><button class='#{options.buttonClass}'>#{options.buttonText}</button></a>"
