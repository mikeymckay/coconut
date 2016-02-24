jQuery.fn.dataTableExt.seconds = (humanDuration) ->
  humanDuration.replace(/^a few/,"1")
  humanDuration.replace(/^an/,"1")
  humanDuration.replace(/^a/,"1")
  [value, unit] = humanDuration.split(" ")
  value = parseInt(value)
  moment.duration(value,unit).asSeconds()

jQuery.fn.dataTableExt.oSort['humanduration-asc']  = (x,y) ->
  x = jQuery.fn.dataTableExt.seconds(x)
  y = jQuery.fn.dataTableExt.seconds(y)
   
  return 0 if x is y
  return -1 if x < y
  return 1 if x > y

jQuery.fn.dataTableExt.oSort['humanduration-desc']  = (x,y) ->
  x = jQuery.fn.dataTableExt.seconds(x)
  y = jQuery.fn.dataTableExt.seconds(y)

  return 0 if x is y
  return 1 if x < y
  return -1 if x > y

class ReportView extends Backbone.View
  initialize: ->
    $("html").append "
      <style>
        .cases{
          display: none;
        }
        .dataTables_wrapper {
          overflow-x: scroll;
          overflow-y: hidden;
        }
      </style>
    "

  el: '#content'

  events:
    "change #weekOptions": "updateFromWeekSelector"
    "change #dateOptions": "update"
    "change #reportOptions": "update"
    "click .toggleDateSelector": "toggleDateSelector"
    "change #summaryField1": "summarySelectorChanged"
    "change #summaryField2": "summarySelector2Changed"
    "change #cluster": "updateCluster"
    "click .toggleDisaggregation": "toggleDisaggregation"
    "click .same-cell-disaggregatable": "toggleDisaggregationSameCell"
    "click .toggle-trend-data": "toggleTrendData"
    "click #downloadMap": "downloadMap"
    "click #downloadLargePembaMap": "downloadLargePembaMap"
    "click #downloadLargeUngujaMap": "downloadLargeUngujaMap"
    "click button:contains(Pemba)": "zoomPemba"
    "click button:contains(Unguja)": "zoomUnguja"
    "change [name=aggregationType]": "updateAnalysis"
    "change #facilityType": "update"
    "change #aggregationArea": "update"
    "change #aggregationPeriod": "update"
    "click #csv": "toggleCSVMode"

  toggleDateSelector: ->
    _(["selectByWeek","selectByDate","dateOptions","weekOptions"]).each (id) -> $("##{id}").toggle()


  updateCluster: ->
    @updateUrl("cluster",$("#cluster").val())
    Coconut.router.navigate(url,true)

  zoomPemba: ->
    @map.fitBounds @bounds["Pemba"]
    @updateUrl("showIsland","Pemba")
    Coconut.router.navigate(url,false)

  zoomUnguja: ->
    @map.fitBounds @bounds["Unguja"]
    @updateUrl("showIsland","Unguja")
    Coconut.router.navigate(url,false)

  updateUrl: (property,value) ->
    urlHash = document.location.hash
    url = if urlHash.match(property)
      regExp = new RegExp("#{property}\\/.*?\\/")
      urlHash.replace(regExp,"#{property}/#{value}/")
    else
      urlHash + "/#{property}/#{value}/"
    document.location.hash = url

  updateUrlShowPlace: (place) ->
    urlHash = document.location.hash
    url = if urlHash.match(/showIsland/)
      urlHash.replace(/showIsland\/.*?\//,"showIsland/#{place}/")
    else
      urlHash + "/showIsland/#{place}/"
    document.location.hash = url
    Coconut.router.navigate(url,false)

  downloadLargePembaMap: ->
    @updateUrl("showIsland","Pemba")
    @updateUrl("mapWidth","2000px")
    @updateUrl("mapHeight","4000px")

  downloadLargeUngujaMap: ->
    @updateUrl("showIsland","Unguja")
    @updateUrl("mapWidth","2000px")
    @updateUrl("mapHeight","4000px")

  downloadMap: ->
    $("#downloadMap").html "Generating downloadable map..."
    html2canvas $('#map'),
      width: @mapWidth
      height: @mapHeight
      proxy: '/map_proxy/proxy.php'
      onrendered: (canvas) ->
        $("#mapData").attr "href", canvas.toDataURL("image/png")
        $("#mapData")[0].click()


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

  updateFromWeekSelector: =>
    if @hasWeekOptions()
      startYearWeek = "#{$('[name=StartYear]').val()}-#{$('[name=StartWeek]').val()}"
      endYearWeek = "#{$('[name=EndYear]').val()}-#{$('[name=EndWeek]').val()}"

      startDate = moment( startYearWeek, 'YYYY-W').startOf("isoweek").format("YYYY-MM-DD")
      endDate = moment( endYearWeek, 'YYYY-W').endOf("isoweek").format("YYYY-MM-DD")
      $('#start').val(startDate)
      $('#end').val(endDate)
      @update()


  update: =>
    reportOptions =
      startDate: $('#start').val()
      endDate: $('#end').val()
      reportType: $('#report-type :selected').text()
      cluster: $("#cluster").val()
      summaryField1: $("#summaryField1").val()
      aggregationPeriod: $("#aggregationPeriod").val()
      aggregationArea: $("#aggregationArea").val()
      facilityType: $("#facilityType").val()

    if moment(reportOptions.endDate) < moment(reportOptions.startDate)
      $("#reportOptionsError").html "Start Date must be before End Date"
      return
    else
      $("#reportOptionsError").html ""

    _.each @locationTypes, (location) ->
      reportOptions[location] = $("##{location} :selected").text()

    url = "reports/" + _.chain(reportOptions).map (value, key) ->
      "#{key}/#{escape(value)}" if value?
    .compact()
    .sort()
    .value()
    .join("/")

    Coconut.router.navigate(url,false)
    @render reportOptions

  hasWeekOptions: =>
    startYear = $('[name=StartYear]').val()
    startWeek = $('[name=StartWeek]').val()
    endYear = $('[name=EndYear]').val()
    endWeek = $('[name=EndWeek]').val()

    return startYear and startWeek and endYear and endWeek

  render: (options) =>
    @reportOptions = options
    @locationTypes = "region, district, constituan, shehia".split(/, /)

    _.each (@locationTypes), (option) ->
      if options[option] is undefined
        this[option] = "ALL"
      else
        this[option] = unescape(options[option])
    @reportType = options.reportType || "Analysis - Cases, Household, Age, Gender, Nets and Travel"
    @startDate = options.startDate || moment(new Date).subtract(7,'days').format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")
    @cluster = options.cluster || "off"
    @summaryField1 = options.summaryField1
    @mapWidth = options.mapWidth || "100%"
    @mapHeight = options.mapHeight || $(window).height()
    @aggregationPeriod = options.aggregationPeriod or "Month"
    @aggregationArea = options.aggregationArea or "Zone"
    @facilityType = options.facilityType or "All"

    if $("#reportHeader").length isnt 0
      @$el.find("#reportContents").html "<img src='images/spinner.gif'/>"
    else
      @$el.html "
        <div id='reportHeader'>
          <style> table.results th.header, table.results td{ font-size:150%; } </style>
          <div style='color:red' id='reportOptionsError'></div>
          <table id='weekOptions'></table>
          <table id='dateOptions'></table>
          <button class='toggleDateSelector' id='selectByWeek'>Select By Week</button>
          <button class='toggleDateSelector' id='selectByDate'>Select By Date</button>
          <table id='reportOptions'></table>
        </div>
        <div id='reportContents'></div>
      "

      # If the dates are week boundaries then preset the week selector to match
      if moment(@startDate).startOf("isoweek").format("YYYY-MM-DD") is @startDate and      moment(@endDate).endOf("isoweek").format("YYYY-MM-DD") is @endDate
        initValues = {
          StartYear: moment(@startDate).format("GGGG")
          StartWeek: moment(@startDate).format("W")
          EndYear: moment(@endDate).format("GGGG")
          EndWeek: moment(@endDate).format("W")
        }

      _(["Start","End"]).each (name) =>

        $("#weekOptions").append @formFilterTemplate
          id: "#{name}Year"
          label: "#{name} Year"
          form: "<select name='#{name}Year'>
            #{
              _([(new Date).getFullYear()..2012]).map (year) ->
                "<option value='#{year}' #{if year.toString() is initValues?["#{name}Year"] then "selected='true'" else ""}>
                  #{year}
                </option>"
              .join("")
            }
            </select>
          "
        # Select current year as default
        $("[name=#{name}Year]").val((new Date()).getFullYear())

        $("#weekOptions").append @formFilterTemplate
          id: "#{name}Week"
          label: "#{name} Week"
          form: "<select name='#{name}Week'>
            <option></option>
            #{
              _([1..53]).map (week) ->
                "<option value='#{week}' #{if week.toString() is initValues?["#{name}Week"] then "selected='true'" else ""}>
                  #{week}
                </option>"
              .join("")
            }
            </select>
            <span id='#{name}WeekAsDate'></span>
          "

      $("#dateOptions").append @formFilterTemplate(
        id: "start"
        label: "Start Date"
        form: "<input id='start' max='#{moment().format("YYYY-MM-DD")}' type='date' value='#{@startDate}'/>"
      )

      $("#dateOptions").append @formFilterTemplate(
        id: "end"
        label: "End Date"
        form: "<input id='end' max='#{moment().format("YYYY-MM-DD")}' type='date' value='#{@endDate}'/>"
      )

      $("#selectByWeek").hide()
      $("#dateOptions").hide()
     
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
            _.map([
              "Analysis - Cases, Household, Age, Gender, Nets and Travel"
              "Case Followup Status"
              "Compare MEEDS or iSMS Weekly Facility Reports With Case Followups"
              "Download Spreadsheet"
              "Epidemic Thresholds"
              "Errors Detected by System"
              "Incidence Graph - cases by week"
              "Issues"
              "Maps"
              "Period Trends compared to previous 3 periods"
              "Rainfall Submission"
              "Users - How fast are followups occuring?"
              "Weekly Facility Reports from MEEDS or iSMS"
              "Weekly Trends compared to previous 3 weeks"
            ], (type) =>
              return if type is "spreadsheet" and User.currentUser.hasRole "researcher"
              "<option #{"selected='true'" if type is @reportType}>#{type}</option>"
            ).join("")
          }
        </select>
        "
      )

    document.title = "Coconut - #{@reportType} #{@startDate}--#{@endDate}"

    console.debug @reportType
    this[@reportType]()

    $('div[data-role=fieldcontain]').fieldcontain()
#    $('select[data-role=selector]').selectmenu()
#    $('input.date').datebox
#      mode: "calbox"
#      dateFormat: "%Y-%m-%d"


  hierarchyOptions: (locationType, location) ->
    if locationType is "region"
      return _(GeoHierarchy.root.children).pluck "name"

    GeoHierarchy.findChildrenNames(locationType.toUpperCase(),location)

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
          <td>
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

  "Users - How fast are followups occuring?": =>

    Reports.userAnalysisForUsers
      # Pass list of usernames
      usernames:  Users.map (user) -> user.username()
      startDate: @startDate
      endDate: @endDate
      success: (userAnalysis) =>

        $("#reportContents").html "
          <style>
            td.number{
              text-align: center;
              vertical-align: middle;
            }
          </style>
          <div id='users'>
            <h1>How fast are followups occuring?</h1>

            <h2>All Users</h2>
            <table style='font-size:150%' class='tablesorter' style=' id='usersReportTotals'>
              <tbody>
                <tr style='font-weight:bold' id='medianTimeFromSMSToCompleteHousehold'><td>Median time from SMS sent to Complete Household</td></tr>
                <tr class='odd' id='cases'><td>Cases</td></tr>
                <tr id='casesWithoutCompleteFacilityAfter24Hours'><td>Cases without completed <b>facility</b> record 24 hours after facility notification</td></tr>
                <tr class='odd' id='casesWithoutCompleteHouseholdAfter48Hours'><td>Cases without complete <b>household</b> record 48 hours after facility notification</td></tr>
                <tr id='casesWithCompleteHousehold'><td>Cases with complete household record</td></tr>
                <tr class='odd' id='medianTimeFromSMSToCaseNotification'><td>Median time from SMS sent to Case Notification on tablet</td></tr>
                <tr id='medianTimeFromCaseNotificationToCompleteFacility'><td>Median time from Case Notification to Complete Facility</td></tr>
                <tr class='odd' id='medianTimeFromFacilityToCompleteHousehold'><td>Median time from Complete Facility to Complete Household</td></tr>
              </tbody>
            </table>


            <h2>By User</h2>
            <table class='tablesorter' style='' id='usersReport'>
              <thead>
                <th>Name</th>
                <th>District</th>
                <th>Cases</th>
                <th>Cases without complete <b>facility</b> record 24 hours after facility notification</th>
                <th>Cases without complete <b>facility</b> record</th>
                <th>Cases without complete <b>household</b> record 48 hours after facility notification</th>
                <th>Cases without complete <b>household</b> record</th>
                <th>Median time from SMS sent to Case Notification on tablet (IQR)</th>
                <th>Median time from Case Notification to Complete Facility (IQR)</th>
                <th>Median time from Complete Facility to Complete Household (IQR)</th>
                <th>Median time from SMS sent to Complete Household (IQR)</th>
              </thead>
              <tbody>
                #{
                  Users.map (user) ->
                    if userAnalysis.dataByUser[user.username()]?
                      "
                      <tr id='#{user.username()}'>
                        <td>#{user.nameOrUsername()}</td>
                        <td>#{user.districtInEnglish() or "-"}</td>
                      </tr>
                      "
                    else ""
                  .join("")
                }
              </tbody>
            </table>
          </div>
        "
        _(userAnalysis.total).each (value,key) ->
          if key is "caseIds"
            ""
          else
            $("tr##{key}").append "<td>#{if _(value).isString() then value else _(value).size()}</td>"

        _(userAnalysis.dataByUser).each (userData,user) ->

          $("tr##{userData.userId}").append "
            <td data-type='num' data-sort='#{_(userData.cases).size()}' class='number'><button type='button' onClick='$(this).parent().children(\"div\").toggle()'>#{_(userData.cases).size()}</button>
              <div style='display:none'>
              #{
                cases = _(userData.cases).keys()
                _(cases).map (caseId) ->
                  "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                .join(" ")
              }
              </div>
            </td>

            <td class='number' data-sort='#{_(userData.casesWithoutCompleteFacilityAfter24Hours).size()}'}>
              <button onClick='$(this).parent().children(\"div\").toggle()' type='button'>#{_(userData.casesWithoutCompleteFacilityAfter24Hours).size() or "-"}</button>
              <div style='display:none'>
              #{
                cases = _(userData.casesWithoutCompleteFacilityAfter24Hours).keys()
                _(cases).map (caseId) ->
                  "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                .join(" ")
              }
              </div>
            </td>


            <td class='number' data-sort='#{_(userData.casesWithoutCompleteFacility).size()}'}>
              <button onClick='$(this).parent().children(\"div\").toggle()' type='button'>#{_(userData.casesWithoutCompleteFacility).size() or "-"}</button>
              <div style='display:none'>
              #{
                cases = _(userData.casesWithoutCompleteFacility).keys()
                _(cases).map (caseId) ->
                  "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                .join(" ")
              }
              </div>
            </td>




            <td class='number' data-sort='#{_(userData.casesWithoutCompleteHouseholdAfter48Hours).size()}'}>
              <button onClick='$(this).parent().children(\"div\").toggle()' type='button'>#{_(userData.casesWithoutCompleteHouseholdAfter48Hours).size() or "-"}</button>
              <div style='display:none'>
              #{
                cases = _(userData.casesWithoutCompleteHouseholdAfter48Hours).keys()
                _(cases).map (caseId) ->
                  "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                .join(" ")
              }
              </div>
            </td>

            <td class='number' data-sort='#{_(userData.casesWithoutCompleteHousehold).size()}'}>
              <button onClick='$(this).parent().children(\"div\").toggle()' type='button'>#{_(userData.casesWithoutCompleteHousehold).size() or "-"}</button>
              <div style='display:none'>
              #{
                cases = _(userData.casesWithoutCompleteHousehold).keys()
                _(cases).map (caseId) ->
                  "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                .join(" ")
              }
              </div>
            </td>


            #{
              _([
                "TimeFromSMSToCaseNotification",
                "TimeFromCaseNotificationToCompleteFacility",
                "TimeFromFacilityToCompleteHousehold",
                "TimeFromSMSToCompleteHousehold"
              ]).map (property) ->
                propertySeconds = "median#{property}Seconds"
                "
                  <td data-sort='#{userData[propertySeconds]}' class='number'>
                    #{userData["median#{property}"] or "-"}
                    (#{userData["quartile1#{property}"] or "-"},#{userData["quartile3#{property}"] or "-"})
                  </td>
                "
            }
          "

        $("#usersReport").dataTable
          aoColumnDefs: [
            "sType": "humanduration"
            "aTargets": [5,6,7,8]
          ]
          aaSorting: [[3,"desc"],[2,"desc"]]
          iDisplayLength: 50
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls_pdf.swf"


  "Maps": ->

    if $("#googleMapsLeafletPlugin").length isnt 1
#      $("body").append "<script src='http://maps.google.com/maps/api/js?v=3&sensor=false'></script>"
      _.delay =>
        $("body").append "<script id='googleMapsLeafletPlugin' type='text/javascript' src='js-libraries/Google.js'></script>"
        console.log "Satellite ready"
        @layerControl.addBaseLayer(new L.Google('SATELLITE'), "Satellite")
      ,4000



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

    $("#reportOptions").append "
      <button>Pemba</button>
      <button>Unguja</button>
    "
    $("#reportOptions button").button()


    $("#reportContents").html "
      Use + - buttons to zoom map. Click and drag to reposition the map. Circles with a darker have multiple cases. Red cases show households with additional positive malaria cases.<br/>
      <div id='map' style='width:#{@mapWidth}; height:#{@mapHeight};'></div>
      <button id='downloadMap' type='button'>Download Map</button>
      <button id='downloadLargeUngujaMap' type='button'>Download Large Pemba Map</button>
      <button id='downloadLargePembaMap' type='button'>Download Large Unguja Map</button>
      <a id='mapData' download='map.png' style='display:none'>Map</a>
      <img src='images/loading.gif' style='z-index:100;position:absolute;top:50%;left:50%;margin-left:21px;margin-right:21px' id='tilesLoadingIndicator'/>
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
              hasAdditionalPositiveCasesAtIndexHousehold: caseResult.hasAdditionalPositiveCasesAtIndexHousehold()
              date: caseResult.Household?.lastModifiedAt
            }
        )

        if locations.length is 0
          $("#map").html "
            <h2>No location information for the range specified.</h2>
          "
          return

        ###
        # Use the average to center the map
        latitudeSum = _.reduce locations, (memo,location) ->
          memo + Number(location.latitude)
        , 0

        longitudeSum = _.reduce locations, (memo,location) ->
          memo + Number(location.longitude)
        , 0

        map = new L.Map('map', {
          center: new L.LatLng(
            latitudeSum/locations.length,
            longitudeSum/locations.length
          )
          zoom: 9
        })
        ###

        @map = new L.Map('map')

        @bounds = {
          "Pemba" : [
            [-4.8587000, 39.8772333] # top right of pemba
            [-5.4858000, 39.5536000] # bottom left of Pemba
          ]
          "Unguja" : [
            [-5.7113500, 39.59] # top right of Unguja
            [-6.541, 39.0945000] # bottom left of unguja
          ]
          "Pemba and Unguja" : [
            [-4.8587000, 39.8772333] # top right of pemba
            [-6.4917667, 39.0945000] # bottom left of unguja
          ]
        }


        @map.fitBounds if @reportOptions.topRight and @reportOptions.bottomLeft
          [@reportOptions.topRight,@reportOptions.bottomLeft]
        else if @reportOptions.showIsland
          @bounds[@reportOptions.showIsland]
        else
          @bounds["Pemba and Unguja"]


        tileLayer = new L.TileLayer 'http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          minZoom: 1
          maxZoom: 12
          attribution: 'Map data © OpenStreetMap contributors'

        tileLayer.on "loading", ->
          $("#tilesLoadingIndicator").show()
        tileLayer.on "load", ->
          $("#tilesLoadingIndicator").hide()

        @map.addLayer tileLayer

        baseLayers = ['OpenStreetMap.Mapnik', 'Stamen.Watercolor', 'Esri.WorldImagery']
        @layerControl = L.control.layers.provided(baseLayers).addTo(@map)

        L.Icon.Default.imagePath = 'images'
        
        if @cluster is "on"
          clusterGroup = new L.MarkerClusterGroup()
          _.each locations, (location) =>
            L.marker([location.latitude, location.longitude])
              .addTo(clusterGroup)
              .bindPopup "#{location.date}: <a href='#show/case/#{location.MalariaCaseID}'>#{location.MalariaCaseID}</a>"
          @map.addLayer(clusterGroup)
        else
          _.each locations, (location) =>
            L.circleMarker([location.latitude, location.longitude],
              "fillColor": if location.hasAdditionalPositiveCasesAtIndexHousehold then "#FF4081" else ""
              "radius": 5
              )
              .addTo(@map)
              .bindPopup "
                 #{location.date}: <a href='#show/case/#{location.MalariaCaseID}'>#{location.MalariaCaseID}</a>
               "



  "Download Spreadsheet": ->

    $("#row-region").hide()
    $("#reportContents").html "
    <a id='spreadsheet' href='http://spreadsheet.zmcp.org/spreadsheet_cleaned/#{@startDate}/#{@endDate}'>Download spreadsheet for #{@startDate} to #{@endDate}</a>
    "
    $("a#spreadsheet").button()


  csv: =>

    Case.updateCaseSpreadsheetDocs
      error: (error) -> console.log error
      success: =>

        question = @reportOptions.question
        questions = "Summary,USSD Notification,Case Notification,Facility,Household,Household Members".split(",")

        Case.loadSpreadsheetHeader
          success: =>
            if question?
              $('body').html(
                "<div>"+
                _(Coconut.spreadsheetHeader[question]).map (heading) ->
                  "\"#{heading}\""
                .join(",") + "--EOR--<br/> </div>"
              )
            else
              $('body').html("")
              _(questions).each (question) ->
                $('body').append(
                  "<div id='#{question.replace(" ","")}'>"+
                  _(Coconut.spreadsheetHeader[question]).map (heading) ->
                    "\"#{heading}\""
                  .join(",") + "--EOR--<br/> </div>"
                )

            $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/caseIDsByDate",
              include_docs: false
              startkey: @startDate
              endkey: @endDate
              success: (result) ->
                caseIds = {}
                _(result.rows).each (row) ->
                  caseIds[row.value] = true

                csvStrings = {}
                _(questions).each (question) -> csvStrings["question"] = ""

              
                Coconut.database.allDocs
                  keys: _(caseIds).chain().keys().map((caseId) -> "spreadsheet_row_#{caseId}").value()
                  include_docs: true
                  success: (result) ->
                    _(result.rows).chain().pluck("doc").each (row) ->
                      _(questions).each (question) ->
                        if row?[question]?
                          csvStrings[question] += row[question] + "<br/>"
                    _(questions).each (question) ->
                      $("div##{question.replace(" ","")}").append csvStrings[question]
                    $('body').append "<span id='finished'></span>"


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
          #{
          _.map fields, (field) ->
            "<th>#{field}</th>"
          .join("")
          }
        "

        $("table#results tbody").append _.map(tableData, (row) ->  "
          <tr>
            #{
            _.map row, (element,index) -> "
              <td>
              #{
                if index is 0
                  "<a href='#show/case/#{element}'>#{element}</a>"
                else
                  element
              }
              </td>
            "
            .join("")
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

  "Summary Tables": ->
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
  

  createTable: (headerValues, rows, id, colspan = 1) ->
   "
      <table #{if id? then "id=#{id}" else ""} class='tablesorter'>
        <thead>
          <tr>
            #{
              _.map(headerValues, (header) ->
                "<th colspan='#{colspan}'>#{header}</th>"
              ).join("")
            }
          </tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
    "

  "Incidence Graph - cases by week": ->
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
    startDate = moment.utc("2012-07-01")
    #startDate = moment.utc("2013-07-01")
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/positiveCases",
      startkey: startDate.year()
      include_docs: false
      success: (result) ->
        casesPerAggregationPeriod = {}

        _.each result.rows, (row) ->
          date = moment(row.key.substr(0,10))
          if row.key.substr(0,2) is "20" and date?.isValid() and date > startDate and date < new moment()
            aggregationKey = date.clone().endOf("isoweek").unix()
            casesPerAggregationPeriod[aggregationKey] = 0 unless casesPerAggregationPeriod[aggregationKey]
            casesPerAggregationPeriod[aggregationKey] += 1

        #_.each casesPerAggregationPeriod, (numberOfCases, date) ->
        #  console.log moment.unix(date).toString() + ": #{numberOfCases}"

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

  "Weekly Trends compared to previous 3 weeks": (options = {}) ->
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
    @["Period Trends compared to previous 3 periods"](options)


  "Period Trends compared to previous 3 periods": (options = {}) ->
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
      
    @reportOptions.startDate = @reportOptions.startDate || moment(new Date).subtract(7,'days').format("YYYY-MM-DD")
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
      optionsArray = options.optionsArray
    else
      amountOfTime = moment(@reportOptions.endDate).diff(moment(@reportOptions.startDate))

      previousOptions = _.clone @reportOptions
      previousOptions.startDate = moment(@reportOptions.startDate).subtract(amountOfTime,"milliseconds").format(Coconut.config.get "date_format")
      previousOptions.endDate = @reportOptions.startDate

      previousPreviousOptions= _.clone @reportOptions
      previousPreviousOptions.startDate = moment(previousOptions.startDate).subtract(amountOfTime, "milliseconds").format(Coconut.config.get "date_format")
      previousPreviousOptions.endDate = previousOptions.startDate

      previousPreviousPreviousOptions= _.clone @reportOptions
      previousPreviousPreviousOptions.startDate = moment(previousPreviousOptions.startDate).subtract(amountOfTime, "milliseconds").format(Coconut.config.get "date_format")
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
        output = @createDisaggregatableCaseGroup(data.disaggregated)
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
                    dataPoints = 0
                    element = _.map results, (result) ->
                      # dont include the final period in average
                      unless (dataPoints+1) is results.length 
                        dataPoints += 1
                        sum += parseInt(dataValue(result[index]))
                      "
                        <td class='period-#{period-=1} trend'></td>
                        <td class='period-#{period} data'>#{renderDataElement(result[index])}</td>
                        #{
                          if period is 0
                            "<td class='average-for-previous-periods'>#{Math.round(sum/dataPoints)}</td>"
                          else  ""
                        }
                      "
                    .join("")
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
      # This is an ugly hack to use local scope to ensure the result order is correct
      anotherIndex = reportIndex
      reportIndex++

      reports = new Reports()
      reports.casesAggregatedForAnalysis
        aggregationLevel: "District"
        startDate: options.startDate
        endDate: options.endDate
        mostSpecificLocation: @mostSpecificLocationSelected()
        success: (data) =>
          anyTravelOutsideZanzibar = _.union(data.travel[district]["Yes outside Zanzibar"], data.travel[district]["Yes within and outside Zanzibar"])

          results[anotherIndex] = [
            title         : "Period"
            text          :  "#{moment(options.startDate).format("YYYY-MM-DD")} -> #{moment(options.endDate).format("YYYY-MM-DD")}"
          ,
            title         : "<b>No. of cases reported at health facilities<b/>"
            disaggregated : data.followups[district].allCases
          ,
            title         : "No. of cases reported at health facilities with <b>complete household visits</b>"
            disaggregated : data.followups[district].casesWithCompleteHouseholdVisit
            appendPercent : data.followups[district].casesWithCompleteHouseholdVisit.length/data.followups[district].allCases.length
          ,
            title         : "Total No. of cases (including cases not reported by facilities) with complete household visits"
            disaggregated : data.followups[district].casesWithCompleteHouseholdVisit
          ,
            title         : "No. of additional <b>household members tested<b/>"
            disaggregated : data.passiveCases[district].indexCaseHouseholdMembers
          ,
            title         : "No. of additional <b>household members tested positive</b>"
            disaggregated : data.passiveCases[district].positiveCasesAtIndexHousehold
            appendPercent : data.passiveCases[district].positiveCasesAtIndexHousehold.length / data.passiveCases[district].indexCaseHouseholdMembers.length
          ,
            title         : "% <b>increase in cases found</b> using MCN"
            percent       : data.passiveCases[district].positiveCasesAtIndexHousehold.length / data.passiveCases[district].indexCases.length
          ,
            title         : "No. of positive cases (index & household) in persons <b>under 5</b>"
            disaggregated : data.ages[district].underFive
            appendPercent : data.ages[district].underFive.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) with at least a <b>facility followup</b>"
            disaggregated : data.totalPositiveCases[district]
          ,
            title         : "Positive Cases (index & household) that <b>slept under a net</b> night before diagnosis"
            disaggregated : data.netsAndIRS[district].sleptUnderNet
            appendPercent : data.netsAndIRS[district].sleptUnderNet.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases from a household that <b>has been sprayed</b> within last #{Coconut.IRSThresholdInMonths} months"
            disaggregated : data.netsAndIRS[district].recentIRS
            appendPercent : data.netsAndIRS[district].recentIRS.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) that <b>did not travel</b>"
            disaggregated : data.travel[district]["No"]
            appendPercent : data.travel[district]["No"].length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) that <b>traveled but only within Zanzibar<b/> last month"
            disaggregated : data.travel[district]["Yes within Zanzibar"]
            appendPercent : data.travel[district]["Yes within Zanzibar"].length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) that <b>traveled outside Zanzibar </b>last month"
            disaggregated : anyTravelOutsideZanzibar
            appendPercent : anyTravelOutsideZanzibar.length / data.totalPositiveCases[district].length
          ]

          renderTable()

  updateAnalysis: =>
    @["Analysis - Cases, Household, Age, Gender, Nets and Travel"]($("[name=aggregationType]:checked").val())


  "Analysis - Cases, Household, Age, Gender, Nets and Travel": (aggregationLevel = "District") ->

    $("#reportContents").html "
      <style>
        td button.same-cell-disaggregatable{
          float:right;
        }
      </style>

      <div id='analysis'>
      <hr/>
      Aggregation Type:
      <input name='aggregationType' type='radio' #{if aggregationLevel is "District" then "checked='true'" else ""} value='District'>District</input>
      <input name='aggregationType' type='radio' #{if aggregationLevel is "Shehia" then "checked='true'" else ""}  value='Shehia'>Shehia</input>
      <hr/>
      <div style='font-style:italic'>Click on a column heading to sort.</div>
      <hr/>
      <img id='analysis-spinner' src='images/spinner.gif'/>
      </div>
    "

    reports = new Reports()
    reports.casesAggregatedForAnalysis
      aggregationLevel: aggregationLevel
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (data) =>
        $("#analysis-spinner").hide()
        headings = [
          aggregationLevel
          "Cases"
          "Complete household visit"
          "%"
          "Missing USSD Notification"
          "Missing Case Notification"
          "Complete facility visit"
          "Without complete facility visit (but with case notification)"
          "%"
          "Without complete facility visit within 24 hours"
          "%"
          "Without complete household visit (but with complete facility visit)"
          "%"
          "Without complete household visit within 48 hours"
          "%"
        ]

        $("#analysis").append "<h2>Cases Followed Up<small> <button onClick='$(\".details\").toggle()'>Toggle Details</button></small></h2>"
        $("#analysis").append @createTable headings, "
          #{
            _.map(data.followups, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.allCases)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.casesWithCompleteHouseholdVisit)}</td>
                  <td>#{@formattedPercent(values.casesWithCompleteHouseholdVisit.length/values.allCases.length)}</td>
                  <td class='missingUSSD details'>#{@createDisaggregatableCaseGroup(values.missingUssdNotification)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.missingCaseNotification)}</td>
                  <td class='details'>#{@createDisaggregatableCaseGroup(values.casesWithCompleteFacilityVisit)}</td>
                  #{
                    withoutcompletefacilityvisitbutwithcasenotification = _.difference(values.casesWithoutCompleteFacilityVisit,values.missingCaseNotification)
                    ""
                  }
                  <td>#{@createDisaggregatableCaseGroup(withoutcompletefacilityvisitbutwithcasenotification)}</td>
                  <td>#{@formattedPercent(withoutcompletefacilityvisitbutwithcasenotification.length/values.allCases.length)}</td>

                  <td>#{@createDisaggregatableCaseGroup(values.noFacilityFollowupWithin24Hours)}</td>
                  <td>#{@formattedPercent(values.noFacilityFollowupWithin24Hours.length/values.allCases.length)}</td>


                  #{
                    withoutcompletehouseholdvisitbutwithcompletefacility = _.difference(values.casesWithoutCompleteHouseholdVisit,values.casesWithCompleteFacilityVisit)
                    ""
                  }

                  <td>#{@createDisaggregatableCaseGroup(withoutcompletehouseholdvisitbutwithcompletefacility)}</td>
                  <td>#{@formattedPercent(withoutcompletehouseholdvisitbutwithcompletefacility.length/values.allCases.length)}</td>


                  <td>#{@createDisaggregatableCaseGroup(values.noHouseholdFollowupWithin48Hours)}</td>
                  <td>#{@formattedPercent(values.noHouseholdFollowupWithin48Hours.length/values.allCases.length)}</td>

                </tr>
              "
            ).join("")
          }
        ", "cases-followed-up"

        _([
          "Complete facility visit"
          "Missing USSD Notification"
        ]).each (column) ->
          $("th:contains(#{column})").addClass "details"
        $(".details").hide()

        
        _.delay ->

          $("table.tablesorter").each (index,table) ->

            _($(table).find("tr:nth-child(1) td").length).times (columnNumber) ->
            #_($(table).find("th").length).times (columnNumber) ->
              return if columnNumber is 0

              maxIndex = null
              maxValue = 0
              columnsTds = $(table).find("td:nth-child(#{columnNumber+1})")
              columnsTds.each (index,td) ->
                return if index is 0
                td = $(td)
                value = parseInt(td.text())
                if value > maxValue
                  maxValue = value
                  maxIndex = index
              $(columnsTds[maxIndex]).addClass "max-value-for-column" if maxIndex
          $(".max-value-for-column ").css("color","#FF4081")
          $(".max-value-for-column ").css("font-weight","bold")
          $(".max-value-for-column button.same-cell-disaggregatable").css("color","#FF4081")

        ,2000


        $("#analysis").append "
          <hr>
          <h2>Index Household and Neighbors</h2>
        "
        $("#analysis").append @createTable """
          District
          No. of cases followed up
          No. of additional index household members tested
          No. of additional index household members tested positive
          % of index household members tested positive
          % increase in cases found using MCN
          No. of additional neighbor households visited
          No. of additional neighbor household members tested
          No. of additional neighbor household members tested positive
        """.split(/\n/), "
          #{
#            console.log (_.pluck data.passiveCases.ALL.householdMembers, "MalariaCaseID").join("\n")
            _.map(data.passiveCases, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.indexCases)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.indexCaseHouseholdMembers.length,values.indexCaseHouseholdMembers)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.positiveCasesAtIndexHousehold.length,values.positiveCasesAtIndexHousehold)}</td>
                  <td>#{@formattedPercent(values.positiveCasesAtIndexHousehold.length / values.indexCaseHouseholdMembers.length)}</td>
                  <td>#{@formattedPercent(values.positiveCasesAtIndexHousehold.length / values.indexCases.length)}</td>

                  <td>#{@createDisaggregatableDocGroup(values.neighborHouseholds.length,values.neighborHouseholds)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.neighborHouseholdMembers.length,values.neighborHouseholdMembers)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.positiveCasesAtNeighborHouseholds.length,values.positiveCasesAtNeighborHouseholds)}</td>

                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Age: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small></h2>
        "
        $("#analysis").append @createTable "District, Total, <5, %, 5<15, %, 15<25, %, >=25, %, Unknown, %".split(/, */), "
          #{
            _.map(data.ages, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.underFive.length,values.underFive)}</td>
                  <td>#{@formattedPercent(values.underFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fiveToFifteen.length,values.fiveToFifteen)}</td>
                  <td>#{@formattedPercent(values.fiveToFifteen.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fifteenToTwentyFive.length,values.fifteenToTwentyFive)}</td>
                  <td>#{@formattedPercent(values.fifteenToTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.overTwentyFive.length,values.overTwentyFive)}</td>
                  <td>#{@formattedPercent(values.overTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.unknown.length,values.overTwentyFive)}</td>
                  <td>#{@formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>

                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Gender: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small></h2>
          <button type='button' onclick='$(\".gender-unknown\").toggle()'>Toggle Unknown</button>
        "
        $("#analysis").append @createTable "District, Total, Male, %, Female, %, Unknown, %".split(/, */), "
          #{
            _.map(data.gender, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.male.length,values.male)}</td>
                  <td>#{@formattedPercent(values.male.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.female.length,values.female)}</td>
                  <td>#{@formattedPercent(values.female.length / data.totalPositiveCases[location].length)}</td>
                  <td style='display:none' class='gender-unknown'>#{@createDisaggregatableDocGroup(values.unknown.length,values.unknown)}</td>

                  <td style='display:none' class='gender-unknown'>#{@formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }

        ", "gender"
        $("table#gender th:nth-child(7)").addClass("gender-unknown").css("display", "none")
        $("table#gender th:nth-child(8)").addClass("gender-unknown").css("display", "none")

        $("#analysis").append "
          <hr>
          <h2>Nets and Spraying: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small></h2>
        "
        $("#analysis").append @createTable "District, Positive Cases (index & household), Slept under a net night before diagnosis, %, Household has been sprayed within last #{Coconut.IRSThresholdInMonths} months, %".split(/, */), "
          #{
            _.map(data.netsAndIRS, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.sleptUnderNet.length,values.sleptUnderNet)}</td>
                  <td>#{@formattedPercent(values.sleptUnderNet.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.recentIRS.length,values.recentIRS)}</td>
                  <td>#{@formattedPercent(values.recentIRS.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Travel History (within past month): <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small></h2>
        "
        $("#analysis").append @createTable """
          #{aggregationLevel}
          Positive Cases
          Only outside Zanzibar
          %
          Only within Zanzibar
          %
          Within Zanzibar and outside
          %
          Any Travel outside Zanzibar
          %
          Any Travel
          %
        """.split(/\n/), "
          #{
            _.map data.travel, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroupWithLength(data.totalPositiveCases[location])}</td>
                  #{
                    _.map """
                      Yes outside Zanzibar
                      Yes within Zanzibar
                      Yes within and outside Zanzibar
                    """.split(/\n/), (travelReportedString) =>
                      "
                        <td>#{@createDisaggregatableDocGroupWithLength(data.travel[location][travelReportedString])}</td>
                        <td>#{@formattedPercent(data.travel[location][travelReportedString].length / data.totalPositiveCases[location].length)}</td>
                      "
                    .join('')
                  }
                  #{
                    anyTravelOutsideZanzibar = _.union(data.travel[location]["Yes outside Zanzibar"], data.travel[location]["Yes within and outside Zanzibar"])
                    ""
                  }
                  <td>#{@createDisaggregatableDocGroupWithLength(anyTravelOutsideZanzibar)}</td>
                  <td>#{@formattedPercent(anyTravelOutsideZanzibar.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@createDisaggregatableDocGroupWithLength(data.travel[location]["Any travel"])}</td>
                  <td>#{@formattedPercent(data.travel[location]["Any travel"].length / data.totalPositiveCases[location].length)}</td>

                </tr>
              "
            .join("")
          }
        "
        , "travel-history-table"
  
        ###
        This looks nice but breaks copy/paste
        _.each [2..5], (column) ->
          $($("#travel-history-table th")[column]).attr("colspan",2)
        ###

        ###
        # dataTable doesn't help with copy/paste (disaggregated values appear) and sorting isn't sorted
        $("#analysis table").dataTable
          aaSorting: [[0,"asc"],[6,"desc"],[5,"desc"]]
          iDisplayLength: 50
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls.swf"
        ###

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


  "Case Followup Status": ->
    $("tr.location").hide()
          
    $("#reportContents").html "
      <style>
        button.not-followed-up-after-48-hours-true{
          background-color:#3F51B5;
          color:white;
          text-shadow: none;
        }
        button.not-complete-facility-after-24-hours-true{
          background-color:3F51B5;
        }
        button.travel-history-false{
          background-color:#FF4081;
        }
        button.no-travel-malaria-positive{
          background-color:FF4081;
        }
        button.malaria-positive{
          background-color: 3F51B5;
        }
        table.tablesorter tbody td.high-risk-shehia{
          color:#3F51B5;
          font-weight:bold;
        }

      </style>
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

      Click on a button for more details about the case. <br/><br/>
      <button class='malaria-positive'><img src='images/householdMember.png'></button> - Positive malaria result found at household.
      <br/>
      <button class='no-travel-malaria-positive'><img src='images/householdMember.png'></button> - Positive malaria result found at household with no travel history (probable local transmission).
      <br/>
      <button class='travel-history-false'><img src='images/household.png'></button> - Index case had no travel history (probable local transmission).
      <br/>
      <button class='not-complete-facility-after-24-hours-true'><img src='images/facility.png'></button> - Case not followed up to facility after 24 hours.
      <br/>
      <span style='font-size:75%;color:#3F51B5;font-weight:bold'>SHEHIA</span> - is a shehia classified as high risk based on previous data.
      <br/>
      <button class='not-followed-up-after-48-hours-true'>caseid</button> - Case not followed up after 48 hours.
      <br/>
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

    tableColumns = ["Case ID","Diagnosis Date","Health Facility District","Shehia","USSD Notification"]
    Coconut.questions.fetch
      success: ->
        tableColumns = tableColumns.concat Coconut.questions.map (question) ->
          question.label()
        _.each tableColumns, (text) ->
          $("table.summary thead tr").append "<th>#{text} (<span id='th-#{text.replace(/\s/,"")}-count'></span>)</th>"

    @getCases
      success: (cases) =>
        _.each cases, (malariaCase) =>

          $("table.summary tbody").append "
            <tr id='case-#{malariaCase.caseID}'>
              <td class='CaseID'>
                <a href='#show/case/#{malariaCase.caseID}'>
                  <button class='not-followed-up-after-48-hours-#{malariaCase.notFollowedUpAfter48Hours()}'>#{malariaCase.caseID}</button>
                </a>
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
              <td class='HealthFacilityDistrict #{if malariaCase.highRiskShehia() then "high-risk-shehia" else ""}'>
                #{
                  malariaCase.shehia()
                }
              </td>
              <td class='USSDNotification'>
                #{@createDashboardLinkForResult(malariaCase,"USSD Notification", "<img src='images/ussd.png'/>")}
              </td>
              <td class='CaseNotification'>
                #{@createDashboardLinkForResult(malariaCase,"Case Notification","<img src='images/caseNotification.png'/>")}
              </td>
              <td class='Facility'>
                #{@createDashboardLinkForResult(malariaCase,"Facility", "<img src='images/facility.png'/>","not-complete-facility-after-24-hours-#{malariaCase.notCompleteFacilityAfter24Hours()}")}
              </td>
              <td class='Household'>
                #{@createDashboardLinkForResult(malariaCase,"Household", "<img src='images/household.png'/>","travel-history-#{malariaCase.indexCaseHasTravelHistory()}")}
              </td>
              <td class='HouseholdMembers'>
                #{
                  _.map(malariaCase["Household Members"], (householdMember) =>
                    malariaPositive = householdMember.MalariaTestResult? and (householdMember.MalariaTestResult is "PF" or householdMember.MalariaTestResult is "Mixed")
                    noTravelPositive = householdMember.OvernightTravelinpastmonth isnt "Yes outside Zanzibar" and malariaPositive
                    buttonText = "<img src='images/householdMember.png'/>"
                    unless householdMember.complete?
                      unless householdMember.complete
                        buttonText = buttonText.replace(".png","Incomplete.png")
                    @createCaseLink
                      caseID: malariaCase.caseID
                      docId: householdMember._id
                      buttonClass: if malariaPositive and noTravelPositive
                       "no-travel-malaria-positive"
                      else if malariaPositive
                       "malaria-positive"
                      else ""
                      buttonText: buttonText
                  ).join("")
                }
              </td>
            </tr>
          "

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

  createDashboardLinkForResult: (malariaCase,resultType,buttonText, buttonClass = "") ->

    if malariaCase[resultType]?
      unless malariaCase[resultType].complete?
        unless malariaCase[resultType].complete
          buttonText = buttonText.replace(".png","Incomplete.png") unless resultType is "USSD Notification"
      @createCaseLink
        caseID: malariaCase.caseID
        docId: malariaCase[resultType]._id
        buttonClass: buttonClass
        buttonText: buttonText
    else ""

  createCaseLink: (options) ->
    options.buttonText ?= options.caseID
    "<a href='#show/case/#{options.caseID}#{if options.docId? then "/" + options.docId else ""}'><button class='#{options.buttonClass}'>#{options.buttonText}</button></a>"


  # Can handle either full case object or just array of caseIDs
  createCasesLinks: (cases) ->
    _.map(cases, (malariaCase) =>
      @createCaseLink  caseID: (malariaCase.caseID or malariaCase)
    ).join("")

  createDisaggregatableCaseGroup: (cases, text) ->
    text = cases.length unless text?
    "
      <button class='sort-value same-cell-disaggregatable'>#{text}</button>
      <div class='cases' style='padding:10px;display:none'>
        <br/>
        #{@createCasesLinks cases}
      </div>
    "

  createDisaggregatableCaseGroupWithLength: (cases) ->
    text = if cases then cases.length else "-"
    @createDisaggregatableCaseGroup cases, text

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

  createDisaggregatableDocGroupWithLength: (docs) =>
    @createDisaggregatableDocGroup docs.length, docs




  "Errors Detected By System": =>
    @renderAlertStructure ["system_errors"]

    Reports.systemErrors
      success: (errorsByType) =>
        if _(errorsByType).isEmpty()
          $("#system_errors").append "No system errors."
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
        @afterFinished()

  "Cases Without Complete Household Visit": =>
    @renderAlertStructure ["not_followed_up"]
  
    Reports.casesWithoutCompleteHouseholdVisit
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (casesWithoutCompleteHouseholdVisit) =>

        if casesWithoutCompleteHouseholdVisit.length is 0
          $("#not_followed_up").append "All cases between #{@startDate} and #{@endDate} have had a complete household visit within two days."
        else
          alerts = true

          $("#not_followed_up").append "
            The following districts have USSD Notifications that occurred between #{@startDate} and #{@endDate} that have not had a completed household visit after two days. Recommendation call the DMSO:
            <table  style='border:1px solid black' class='alerts'>
              <thead>
                <tr>
                  <th>Facility</th>
                  <th>District</th>
                  <th>Officer</th>
                  <th>Phone number</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(casesWithoutCompleteHouseholdVisit, (malariaCase) ->
                    district = malariaCase.district() || "UNKNOWN"
                    return "" if district is "ALL" or district is "UNKNOWN"

                    user = Users.where(
                      district: district
                    )
                    user = user[0] if user.length

                    "
                      <tr>
                        <td>#{malariaCase.facility()}</td>
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
        @afterFinished()

  "Cases With Unknown Districts": =>
    @renderAlertStructure ["unknown_districts"]

    Reports.unknownDistricts
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (casesWithoutCompleteHouseholdVisitWithUnknownDistrict) =>

        if casesWithoutCompleteHouseholdVisitWithUnknownDistrict.length is 0
          $("#unknown_districts").append "All cases between #{@startDate} and #{@endDate} that have not been followed up have shehias with known districts"
        else
          alerts = true

          $("#unknown_districts").append "
            The following cases have not been followed up and have shehias with unknown districts (for period #{@startDate} to #{@endDate}. These may be traveling patients or incorrectly spelled shehias. Please contact an administrator if the problem can be resolved by fixing the spelling.
            <table style='border:1px solid black' class='unknown-districts'>
              <thead>
                <tr>
                  <th>Health facility</th>
                  <th>Shehia</th>
                  <th>Case ID</th>
                </tr>
              </thead>
              <tbody>
                #{
                  _.map(casesWithoutCompleteHouseholdVisitWithUnknownDistrict, (caseNotFollowedUpWithUnknownDistrict) ->
                    "
                      <tr>
                        <td>#{caseNotFollowedUpWithUnknownDistrict["USSD Notification"].hf.titleize()}</td>
                        <td>#{caseNotFollowedUpWithUnknownDistrict.shehia().titleize()}</td>
                        <td><a href='#show/case/#{caseNotFollowedUpWithUnknownDistrict.caseID}'>#{caseNotFollowedUpWithUnknownDistrict.caseID}</a></td>
                      </tr>
                    "
                  ).join("")
                }
              </tbody>
            </table>
          "
        afterFinished()


  "Tablet Sync": (options) =>
    startDate = moment(@startDate)
    endDate = moment(@endDate).endOf("day")
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/syncLogByDate",
      startkey: @startDate
      endkey: moment(@endDate).endOf("day").format("YYYY-MM-DD HH:mm:ss") # include all entries for today
      include_docs: false
      success: (syncLogResult) =>

        users = new UserCollection()
        users.fetch
          error: (error) -> console.error "Couldn't fetch UserCollection"
          success: =>

            numberOfDays = endDate.diff(startDate, 'days') + 1

            # call this from user list perspective and sync list perspective in case they don't match
            initializeEntryForUser = (user) =>
              numberOfSyncsPerDayByUser[user] = {}
              _(numberOfDays).times( (dayNumber) =>
                numberOfSyncsPerDayByUser[user][moment(@startDate).add(dayNumber,"days").format("YYYY-MM-DD")] = 0
              )

            numberOfSyncsPerDayByUser = {}
            _(users.models).each (user) =>
              initializeEntryForUser(user.get("_id")) if user.district()? and not (user.get("inactive") is "true" or user.get("inactive"))

            _(syncLogResult.rows).each (syncEntry) =>
              unless numberOfSyncsPerDayByUser[syncEntry.value]?
                initializeEntryForUser(syncEntry.value)
              numberOfSyncsPerDayByUser[syncEntry.value][moment(syncEntry.key).format("YYYY-MM-DD")] += 1

            $("#reportContents").html "
              <br/>
              <br/>
              Number of Syncs Performed by User<br/>
              <br/>
              <table id='syncLogTable'>
                <thead>
                  <th>District</th>
                  <th>Name</th>
                  #{
                    _(numberOfDays).times( (dayNumber) =>
                      "<th>#{moment(@startDate).add(dayNumber, "days").format("YYYY-MM-DD")}</th>"
                    ).join("")
                  }
                </thead>
                <tbody>
                #{
                  _(numberOfSyncsPerDayByUser).map( (data,user) ->
                    if not users.get(user)?
                      console.error "Could not find user: #{user}"
                      return
                    "
                      <tr>
                        <td>#{users.get(user).district()}</td>
                        <td>#{users.get(user).get("name")}</td>
                        #{
                          _(numberOfSyncsPerDayByUser[user]).map( (value, day) ->
                            color =
                              if value is 0
                                "#FFCCFF"
                              else if value <= 5
                                "#C5CAE9"
                              else
                                "#8AFF8A"
                            "<td style='text-align:center; background-color: #{color}'>#{value}</td>"
                          ).join("")
                        }
                      </tr>
                    "
                  ).join("")
                }
                </tbody>
              </table>
            "

            $("#syncLogTable").dataTable
              aaSorting: [[0,"asc"]]
              iDisplayLength: 50
              dom: 'T<"clear">lfrtip'
              tableTools:
                sSwfPath: "js-libraries/copy_csv_xls_pdf.swf"

            $("#syncLogTable_length").hide()
            $("#syncLogTable_info").hide()
            $("#syncLogTable_paginate").hide()








  "Weekly Facility Reports from MEEDS or iSMS": (options) =>
    $("#row-region").hide()

    Reports.aggregateWeeklyReportsAndFacilityCases
      startDate: @startDate
      endDate: @endDate
      aggregationArea: @aggregationArea
      aggregationPeriod: @aggregationPeriod
      success: (results) =>
        console.log results

        $("#reportContents").html "
          <style>
            td.number{
              text-align: center;
              vertical-align: middle;
            }
          </style>
          <br/>
          <br/>
          <h1>
            Weekly Facility Reports from MEEDS or iSMS aggregated by 
            <select style='height:50px;font-size:115%' id='aggregationPeriod'>
              #{
                _("Year,Month,Week".split(",")).map (aggregationPeriod) =>
                  "
                    <option #{if aggregationPeriod is @aggregationPeriod then "selected='true'" else ''}>
                      #{aggregationPeriod}
                    </option>"
                .join ""
              }
            </select>
            and
            <select style='height:50px;font-size:115%' id='aggregationArea'>
              #{
                _("Zone,District,Facility".split(",")).map (aggregationArea) =>
                  "
                    <option #{if aggregationArea is @aggregationArea then "selected='true'" else ''}>
                      #{aggregationArea}
                    </option>"
                .join ""
              }
            </select>
          </h1>
          <br/>
          <table class='tablesorter' id='weeklyReports'>
            <thead>
              <th>#{@aggregationPeriod}</th>
              <th>#{@aggregationArea}</th>
              #{
                _.map results.fields, (field) ->
                  "<th>#{field}</th>"
                .join("")
              }
              <th>Weekly Reports Positive Cases</th>
              <th><5 Test Rate</th>
              <th><5 POS Rate</th>
              <th>=>5 Test Rate</th>
              <th>>=5 POS Rate</th>
            </thead>
            <tbody>
              #{
                _(results.data).map (aggregationAreas, aggregationPeriod) =>
                  _(aggregationAreas).map (data,aggregationArea) =>

                    # TODO fix this - we shouldn't skip unknowns
                    if aggregationArea is "Unknown"
                      console.error "Unknown aggregation area for:"
                      console.error data
                      return if aggregationArea is "Unknown"
                    "
                      <tr>
                        <td>#{aggregationPeriod}</td>
                        <td>#{aggregationArea}</td>
                        #{
                        _.map results.fields, (field) =>
                          if field is "Facility Followed-Up Positive Cases"
                            "<td>#{@createDisaggregatableCaseGroupWithLength data[field]}</td>"
                          else
                            "<td>#{if data[field]? then data[field] else "-"}</td>"
                        .join("")
                        }
                        <td>
                          #{
                            total = data["Mal POS < 5"]+data["Mal POS >= 5"]
                            if Number.isNaN(total) then '-' else total
                          }
                        </td>
                        #{
                          percentElement = (number) ->
                            if Number.isNaN(number)
                              "<td>-</td>"
                            else
                              "<td>#{Math.round(number * 100)}%</td>"
                          ""
                        }

                        #{percentElement ((data["Mal POS < 5"]+data["Mal NEG < 5"])/data["All OPD < 5"])}
                        #{percentElement (data["Mal POS < 5"]/(data["Mal NEG < 5"]+data["Mal POS < 5"]))}
                        #{percentElement ((data["Mal POS >= 5"]+data["Mal NEG >= 5"])/data["All OPD >= 5"])}
                        #{percentElement (data["Mal POS >= 5"]/(data["Mal NEG >= 5"]+data["Mal POS >= 5"]))}

                      </tr>
                    "
                  .join("")
                .join("")
              }
            </tbody>
          </table>
        "

        $("#weeklyReports").dataTable
          aaSorting: [[0,"desc"],[1,"asc"],[2,"desc"]]
          iDisplayLength: 50
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls.swf"
            aButtons: [
              "copy",
              "csv",
              "print"
            ]

  "Rainfall Submission": () =>
    $("#row-region").hide()
    Coconut.database.view "zanzibar-server/rainfallDataByDateAndLocation",
      startkey: [moment(@startDate).year(), moment(@startDate).week()]
      endkey: [moment(@endDate).year(), moment(@endDate).week()]
      error: (error) ->
        Coconut.debug "Error: #{JSON.stringify error}"
        options.error?(error)
      success: (results) =>
        $("#reportContents").html "
          <style>
            td.number{
              text-align: center;
              vertical-align: middle;
            }
          </style>
          <br/>
          <br/>
          <h1>
            Rainfall Data Submissions
          </h1>
          <br/>
          <table class='tablesorter' id='rainfallReports'>
            <thead>
              <th>Station</th>
              <th>Year</th>
              <th>Week</th>
              <th>Amount</th>
            </thead>
            <tbody>
              #{
                _(results.rows).map (row) =>
                  "
                    <tr>
                      <td>#{row.value[0]}</td>
                      <td>#{row.key[0]}</td>
                      <td>#{row.key[1]}</td>
                      <td>#{row.value[1]}</td>
                    </tr>
                  "
                .join("")
              }
            </tbody>
          </table>
        "

        $("#rainfallReports").dataTable
          aaSorting: [[1,"desc"],[2,"desc"]]
          iDisplayLength: 50
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls.swf"
            aButtons: [
              "copy",
              "csv",
              "print"
            ]
 
  toggleCSVMode: () =>
    if @csvMode then @csvMode = false else @csvMode = true
    @renderFacilityTimeliness()
   
  renderFacilityTimeliness: =>
    $("#reportContents").html "
      <style>
        td.number{
          text-align: center;
          vertical-align: middle;
        }
        table.tablesorter tbody td.mismatch, button.mismatch, span.mismatch{
          color:#FF4081
        }
      </style>
      <br/>
      <br/>
      <h1>
        MEEDS or iSMS Weekly Reports and Coconut cases aggregated by 
        <select style='height:50px;font-size:115%' id='aggregationPeriod'>
          #{
            _("Year,Quarter,Month,Week".split(",")).map (aggregationPeriod) =>
              "
                <option #{if aggregationPeriod is @aggregationPeriod then "selected='true'" else ''}>
                  #{aggregationPeriod}
                </option>"
            .join ""
          }
        </select>
        and
        <select style='height:50px;font-size:115%' id='aggregationArea'>
          #{
            _("Zone,District,Facility".split(",")).map (aggregationArea) =>
              "
                <option #{if aggregationArea is @aggregationArea then "selected='true'" else ''}>
                  #{aggregationArea}
                </option>"
            .join ""
          }
        </select>

        for <select style='height:50px;font-size:115%' id='facilityType'>
          #{
            _("All,Private,Public".split(",")).map (facilityType) =>
              "
                <option #{if facilityType is @facilityType then "selected='true'" else ''}>
                  #{facilityType}
                </option>"
            .join ""
          }
        </select>
        facilities.
      </h1>
      <div>If the total positive cases from the weekly reports don't match the number of cases notified, the <span class='mismatch'>mismatched values are colored</span>.</div>
      <button style='float:right' id='csv'>#{if @csvMode then "Table Mode" else "CSV Mode"}</button>
      <br/>
      <br/>
      <table class='tablesorter' id='facilityTimeliness' style='#{if @csvMode then "display:none" else ""}'>
        <thead>
          <th>#{@aggregationPeriod}</th>
          <th>Zone</th>
          #{if @aggregationArea is "District" or @aggregationArea is "Facility" then "<th>District</th>" else ""}
          #{if @aggregationArea is "Facility" then "<th>Facility</th>"  else ""}
          <th>Reports expected for period</th>
          <th>Reports submitted for period</th>
          <th>Percent submitted for period</th>
          <th>Reports submitted within 1 day of period end (Monday)</th>
          <th>Reports submitted within 1-3 days of period end (by Wednesday)</th>
          <th>Reports submitted within 3-5 days of period end (by Friday)</th>
          <th>Reports submitted 7 or more days after period end</th>
          <th>Total Tested</th>
          <th>Total Positive (%)</th>
          <th>Number of cases notified</th>
          <th>Facility Followed-Up Positive Cases</th>
          <th>Cases Followed-Up within 48 Hours</th>
          <th>Median Days from Positive Test Result to Facility Notification (IQR)</th>
          <th>Median Days from Facility Notification to Complete Facility (IQR)</th>
          <th>% of Notified Cases with Complete Facility Followup</th>
          <th>Median Days from Facility Notification to Complete Household (IQR)</th>
          <th>% of Notified Cases with Complete Household Followup</th>
          <th>Number of Household or Neighbor Members</th>
          <th>Number of Household or Neighbor Members Tested (%)</th>
          <th>Number of Household or Neighbor Members Tested Positive (%)</th>
        </thead>
        <tbody>
          #{
            quartilesAndMedian = (values)->
              [median,h1Values,h2Values] = getMedianWithHalves(values)
              [
                getMedian(h1Values)
                median
                getMedian(h2Values)
              ]

            getMedianWithHalves = (values) ->

              return [ values[0], [values[0]], [values[0]] ] if values.length is 1

              values.sort  (a,b)=> return a - b
              half = Math.floor values.length/2
              if values.length % 2 #odd
                median = values[half]
                return [median,values[0..half],values[half...]]
              else # even
                median = (values[half-1] + values[half]) / 2.0
                return [median, values[0..half],values[half+1...]]


            getMedian = (values)->
              getMedianWithHalves(values)[0]

            getMedianOrEmptyFormatted = (values)->
              return "-" unless values?
              Math.round(getMedian(values)*10)/10

            getMedianAndQuartilesElement = (values)->
              return "-" unless values?
              [q1,median,q3] = _(quartilesAndMedian(values)).map (value) ->
                Math.round(value*10)/10
              "#{median} (#{q1}-#{q3})"

            getNumberAndPercent = (numerator,denominator) ->
              return "-" unless numerator? and denominator?
              "#{numerator} (#{Math.round(numerator/denominator*100)}%)"

            allPrivateFacilities = FacilityHierarchy.allPrivateFacilities()

            _(@results.data).map (aggregationAreas, aggregationPeriod) =>
              _(aggregationAreas).map (data,aggregationArea) =>

                # TODO fix this - we shouldn't skip unknowns
                return if aggregationArea is "Unknown"
                "
                  <tr>
                    <td>#{aggregationPeriod}</td>
                    #{
                      if @aggregationArea is "Facility"
                        "
                        <td>#{FacilityHierarchy.getZone(aggregationArea)}</td>
                        <td>#{FacilityHierarchy.getDistrict(aggregationArea)}</td>
                        "
                      else if @aggregationArea is "District"
                        "
                        <td>#{GeoHierarchy.getZoneForDistrict(aggregationArea)}</td>
                        "
                      else ""
                    }
                    <td>
                      #{aggregationArea}
                      #{if @aggregationArea is "Facility" and _(allPrivateFacilities).contains(aggregationArea) then "(private)" else ""}
                    </td>
                    <td>
                      #{
                        numberOfFaciltiesMultiplier = if @aggregationArea is "Zone"
                          FacilityHierarchy.facilitiesForZone(aggregationArea).length
                        else if @aggregationArea is "District"
                          FacilityHierarchy.facilitiesForDistrict(aggregationArea).length
                        else
                          1

                        expectedNumberOfReports = switch @aggregationPeriod
                          when "Year" then 52
                          when "Month" then "4"
                          when "Quarter" then "13"
                          when "Week" then "1"
                        expectedNumberOfReports = expectedNumberOfReports * numberOfFaciltiesMultiplier
                      }
                    </td>
                    <td>#{numberReportsSubmitted = data["Reports submitted for period"] or 0}</td>
                    <td>
                      #{
                        if Number.isNaN(numberReportsSubmitted) or Number.isNaN(expectedNumberOfReports) or expectedNumberOfReports is 0
                          '-'
                        else
                          Math.round(numberReportsSubmitted/expectedNumberOfReports * 1000)/10 + "%"
                      }
                    </td>
                    <td>#{data["Report submitted within 1 day"] or 0}</td>
                    <td>#{data["Report submitted within 1-3 days"] or 0}</td>
                    <td>#{data["Report submitted within 3-5 days"] or 0}</td>
                    <td>#{data["Report submitted 5+ days"] or 0}</td>
                    <td>
                      <!-- Total Tested -->
                      #{
                        totalTested = data["Mal POS < 5"]+data["Mal POS >= 5"]+data["Mal NEG < 5"]+data["Mal NEG >= 5"]
                        if Number.isNaN(totalTested) then '-' else totalTested
                      }

                    </td>
                    <td class='total-positive'>
                      #{
                        totalPositive = data["Mal POS < 5"]+data["Mal POS >= 5"]
                        if Number.isNaN(totalPositive) then '-' else totalPositive
                      }
                      (#{
                        if Number.isNaN(totalTested) or Number.isNaN(totalPositive) or totalTested is 0
                          '-'
                        else
                          Math.round(totalPositive/totalTested * 1000)/10 + "%"
                      })
                    </td>
                    #{
                      _(["casesNotified","hasCompleteFacility","followedUpWithin48Hours"]).map (property) =>
                        "
                          <td class='#{property}'>
                            #{
                              if @csvMode
                                data[property]?.length or "-"
                              else
                                if data[property] then @createDisaggregatableCaseGroupWithLength data[property] else '-'
                            }
                          </td>
                        "
                      .join ""
                    }
                          
                    <td>#{getMedianAndQuartilesElement data["daysBetweenPositiveResultAndNotification"]}</td>
                    <td>#{getMedianAndQuartilesElement data["daysFromCaseNotificationToCompleteFacility"]}</td>
                    <td>
                    #{
                      if data["casesNotified"] and data["casesNotified"].length isnt 0 and data["Facility Followed-Up Positive Cases"]
                        Math.round(data["Facility Followed-Up Positive Cases"].length / data["casesNotified"].length * 1000)/10 + "%"
                      else
                        "-"
                    }
                    </td>
                    <td>#{getMedianAndQuartilesElement data["daysFromSMSToCompleteHousehold"]}</td>
                    <td>
                    #{
                      if data["casesNotified"] and data["casesNotified"].length isnt 0 and data["householdFollowedUp"]
                        Math.round(data["householdFollowedUp"] / data["casesNotified"].length * 1000)/10 + "%"
                      else
                        "-"
                    }
                    </td>
                    <td>
                      #{data["numberHouseholdOrNeighborMembers"] || "-"}
                    </td>
                    <td>
                      #{getNumberAndPercent(data["numberHouseholdOrNeighborMembersTested"],data["numberHouseholdOrNeighborMembers"])}
                    </td>
                    <td>
                      #{getNumberAndPercent(data["numberPositiveCasesAtIndexHouseholdAndNeighborHouseholds"],data["numberHouseholdOrNeighborMembersTested"])}
                    </td>
                  </tr>
                "
              .join("")
            .join("")
          }
        </tbody>
      </table>
    "

    $("#facilityTimeliness").dataTable
      aaSorting: [[0,"desc"]]
      iDisplayLength: 50
      dom: 'T<"clear">lfrtip'
      tableTools:
        sSwfPath: "js-libraries/copy_csv_xls.swf"
        aButtons: [
          "csv",
        ]
      fnDrawCallback: ->
        # Check for mismatched cases
        _($("tr")).each (tr) ->
          totalPositiveElement = $(tr).find("td.total-positive")
          
          if totalPositiveElement? and totalPositiveElement.text() isnt ""
            totalPositive = totalPositiveElement.text().match(/[0-9|-]+ /)[0]
            
          casesNotified = $(tr).find("td.casesNotified button.sort-value").text() or 0

          if parseInt(totalPositive) isnt parseInt(casesNotified)
            totalPositiveElement.addClass("mismatch")
            $(tr).find("td.casesNotified button.sort-value").addClass("mismatch")
            $(tr).find("td.casesNotified").addClass("mismatch")

    if @csvMode
      $(".dataTables_filter").hide()
      $(".dataTables_paginate").hide()
      $(".dataTables_length").hide()
      $(".dataTables_info").hide()
    else
      $(".DTTT_container").hide()

  "Compare MEEDS or iSMS Weekly Facility Reports With Case Followups": () =>
    $("#row-region").hide()

    Reports.aggregateWeeklyReportsAndFacilityTimeliness
      startDate: @startDate
      endDate: @endDate
      aggregationArea: @aggregationArea
      aggregationPeriod: @aggregationPeriod
      facilityType: @facilityType
      success: (results) =>
        @results = results
        @renderFacilityTimeliness()


  "Epidemic Thresholds": =>
    $("#row-region").hide()

    # Thresholds per facility per week
    thresholdFacility = 10
    thresholdFacilityUnder5s = 5
    thresholdShehia = 10
    thresholdShehiaUnder5 = 5
    thresholdVillage = 5


    $("#reportContents").html "
      <h2>Epidemic Thresholds</h2>

      Alerts:<br/>
      <ul>
        <li>Facility with #{thresholdFacility} or more cases</li>
        <li>Facility with #{thresholdFacilityUnder5s} or more cases in under 5s</li>
        <li>Shehia with #{thresholdShehia} or more cases</li>
        <li>Shehia with #{thresholdShehiaUnder5} or more cases in under 5s</li>
        <li>Village (household + neighbors) with  #{thresholdVillage} or more cases</li>
        <li>District - statistical method (todo)</li>
      </ul>
    "
    startDate = moment(@startDate)
    startYear = startDate.format("GGGG") # ISO week year
    startWeek =startDate.format("WW")
    endDate = moment(@endDate).endOf("day")
    endYear = endDate.format("GGGG")
    endWeek = endDate.format("WW")
    weekRange = []
    moment.range(startDate,endDate).by 'week', (moment) ->
      weekRange.push moment.format("YYYY-WW")

    alerts = [
      "alert-weekly-facility-total-cases"
      "alert-weekly-facility-under-5-cases"
      "alert-weekly-shehia-cases"
      "alert-weekly-shehia-under-5-cases"
      "alert-weekly-village-cases"
    ]

    alertsByDistrictAndWeek = {}

    finished = _.after alerts.length, ->
      $("#reportContents").append "

        <table class='tablesorter' id='thresholdTable'>
          <thead>
            <th>District</th>
            #{
              _(weekRange).map (week) ->
                "<th>#{week}</th>"
              .join("")
            }
          </thead>
          <tbody>
            #{
              _(GeoHierarchy.allDistricts()).map (district) ->
                "
                <tr> 
                  <td>#{district}</td>
                  #{
                  _(weekRange).map (week) ->
                    "
                    <td>
                      #{
                        _(alertsByDistrictAndWeek[district]?[week]).map (alert) ->
                          "<small><a href='#show/issue/#{alert._id}'>#{alert.Description}</a></small>"
                        .join("<br/>")
                      }
                    </td>
                    "
                  .join("")
                  }
                </tr>
                "
              .join("")
            }
          </tbody>
        </table>
      "
      $("#thresholdTable").dataTable
        aaSorting: [[0,"desc"]]
        iDisplayLength: 50
        dom: 'T<"clear">lfrtip'
        tableTools:
          sSwfPath: "js-libraries/copy_csv_xls.swf"
          aButtons: [
            "csv",
            ]

    _(alerts).each (alert) ->
      Coconut.database.allDocs
        startkey: "#{alert}-#{startYear}-#{startWeek}"
        endkey: "#{alert}-#{endYear}-#{endWeek}-\ufff0"
        include_docs: true
        error: (error) -> console.log error
        success: (result) ->
          _(result.rows).each (row) ->
            alert = row.doc
            alertsByDistrictAndWeek[alert.District] = {} unless alertsByDistrictAndWeek[alert.District]
            alertsByDistrictAndWeek[alert.District][alert.Week] = [] unless alertsByDistrictAndWeek[alert.District][alert.Week]
            alertsByDistrictAndWeek[alert.District][alert.Week].push alert
          finished()


  "Issues": =>
    $("#row-region").hide()

    $("#reportContents").html "
      <h2>Issues</h2>
        <a href='#new/issue'>Create New Issue</a>
        <br/>
        <br/>
        <table class='tablesorter' id='issuesTable'>
          <thead>
            <th>Description</th>
            <th>Date Created</th>
            <th>Assigned To</th>
            <th>Date Resolved</th>
          </thead>
          <tbody>
          </tbody>
        </table>
    "

    Reports.getIssues
      startDate: @startDate
      endDate: @endDate
      error: (error) -> console.log error
      success: (issues) ->
        console.log issues
        $("#issuesTable tbody").html _(issues).map (issue) ->

          date = if issue.Week
            moment(issue.Week, "GGGG-WW").format("YYYY-MM-DD")
          else
            issue["Date Created"]

          "
          <tr>
            <td><a href='#show/issue/#{issue._id}'>#{issue.Description}</a></td>
            <td>#{date}</td>
            <td>#{issue["Assigned To"] or "-"}</td>
            <td>#{issue["Date Resolved"] or "-"}</td>
          </tr>
          "

        $("#issuesTable").dataTable
          aaSorting: [[1,"desc"]]
          iDisplayLength: 50
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls.swf"
            aButtons: [
              "csv",
              ]



