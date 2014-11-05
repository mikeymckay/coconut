jQuery.fn.dataTableExt.seconds = (humanDuration) ->
  [value, unit] = humanDuration.split(" ")
  value = 1 if value is "a" or value is "an" or value is "a few"
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
USSD}
      </style>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"
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
    @mapWidth = options.mapWidth || "100%"
    @mapHeight = options.mapHeight || $(window).height()

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
          _.map(["dashboard","locations","spreadsheet","summarytables","analysis","alerts", "weeklySummary","periodSummary","incidenceGraph","systemErrors","casesWithoutCompleteHouseholdVisit","casesWithUnknownDistricts","tabletSync","clusters", "pilotNotifications", "users", "weeklyReports"], (type) =>
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



  renderAlertStructure: (alerts_to_check)  =>
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

    @alerts = false

    # Don't call this until all alert checks are complete
    @afterFinished = _.after(alerts_to_check.length, ->
      if @alerts
        $("#alerts_status").html("<div id='hasAlerts'>Report finished, alerts found.</div>")
      else
        $("#alerts_status").html("<div id='hasAlerts'>Report finished, no alerts found.</div>")
    )


  alerts: =>
    @renderAlertStructure  "system_errors, not_followed_up, unknown_districts".split(/, */)

    Reports.systemErrors
      success: (errorsByType) =>
        if _(errorsByType).isEmpty()
          $("#system_errors").append "No system errors in the past 2 days."
        else
          @alerts = true

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
  
    Reports.casesWithoutCompleteHouseholdVisit
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (casesWithoutCompleteHouseholdVisit) =>

        if casesWithoutCompleteHouseholdVisit.length is 0
          $("#not_followed_up").append "All cases between #{@startDate} and #{@endDate} have been followed up within two days."
        else
          @alerts = true

          $("#not_followed_up").append "
            The following districts have USSD Notifications that occurred between #{@startDate} and #{@endDate} that have not been followed up after two days. Recommendation call the DMSO:
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
        
        Reports.unknownDistricts
          startDate: @startDate
          endDate: @endDate
          mostSpecificLocation: @mostSpecificLocationSelected()
          success: (casesNotFollowedupWithUnknownDistrict) =>

            if casesNotFollowedupWithUnknownDistrict.length is 0
              $("#unknown_districts").append "All cases between #{@startDate} and #{@endDate} that have not been followed up have shehias with known districts"
            else
              @alerts = true

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
                      _.map(casesNotFollowedupWithUnknownDistrict, (caseNotFollowedUpWithUnknownDistrict) ->
                        console.log JSON.stringify caseNotFollowedUpWithUnknownDistrict
                        "
                          <tr>
                            <td>#{caseNotFollowedUpWithUnknownDistrict["USSD Notification"]?.hf.titleize()}</td>
                            <td>#{caseNotFollowedUpWithUnknownDistrict.shehia().titleize()}</td>
                            <td><a href='#show/case/#{caseNotFollowedUpWithUnknownDistrict.caseID}'>#{caseNotFollowedUpWithUnknownDistrict.caseID}</a></td>
                          </tr>
                        "
                      ).join("")
                    }
                  </tbody>
                </table>
              "
            @afterFinished()

  clusters: ->
    clusterThreshold = 1000
    reports = new Reports()
    reports.positiveCaseLocations
      startDate: @startDate
      endDate: @endDate
      success: (positiveCases) ->
        clusteredCases = []
        console.log positiveCases
        for foo, bar in positiveCases
          console.log foo
        result = _(positiveCases).map (cluster) ->
          console.log "ASDAS"
          console.log cluster


        result = _.chain(positiveCases).map (cluster, positiveCase) ->
          console.log "ASDAS"
          console.log cluster
          if (cluster[clusterThreshold].length) > 4
            console.log cluster[clusterThreshold]
            return cluster[clusterThreshold]
          return null
        .compact().sortBy (cluster) ->
          return cluster.length
        .map (cluster) ->
          console.log cluster
          for positiveCase in cluster
            if clusteredCases[positiveCase.MalariaCaseId]
              return null
            else
              clusteredCases[positiveCase.MalariaCaseId] = true
              return cluster
        .compact().value()

        console.log result

            
  users: =>

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/users",
      include_docs: false
      success: (usersView) =>
        $("#reportContents").html "
          <style>
            td.number{
              text-align: center;
              vertical-align: middle;
            }
          </style>
          <div id='users'>
            <h1>How fast are followups occuring?</h1>

            <h2>Median</h2>
            <table style='font-size:150%' class='tablesorter' style=' id='usersReportTotals'>
              <tbody>
                <tr class='odd' style='font-weight:bold' id='medianTimeFromSMSToCompleteHousehold'><td>Median time from SMS sent to Complete Household</td></tr>
                <tr id='cases'><td>Cases</td></tr>
                <tr class='odd' id='casesWithoutCompleteHousehold'><td>Cases without complete household record</td></tr>
                <tr id='casesWithCompleteHousehold'><td>Cases with complete household record</td></tr>
                <tr class='odd' id='medianTimeFromSMSToCaseNotification'><td>Median time from SMS sent to Case Notification on tablet</td></tr>
                <tr id='medianTimeFromCaseNotificationToCompleteFacility'><td>Median time from Case Notification to Complete Facility</td></tr>
                <tr class='odd' id='medianTimeFromFacilityToCompleteHousehold'><td>Median time from Complete Facility to Complete Household</td></tr>
                <tr style='display:none' id='caseIds'><td>Case IDs</td></tr>
              </tbody>
            </table>


            <h2>By User</h2>
            <table class='tablesorter' style='' id='usersReport'>
              <thead>
                <th>Name</th>
                <th>District</th>
                <th>Cases</th>
                <th style='display:none' class='cases'>Case IDs</th>
                <th>Cases without complete household record</th>
                <th style='display:none' class='casesWithoutCompleteHousehold'>Case IDs for Cases Without Complete Household</th>
                <th>Cases with complete household record</th>
                <th style='display:none' class='casesWithCompleteHousehold'>Case IDs for Cases With Complete Household</th>
                <th>Median time from SMS sent to Case Notification on tablet</th>
                <th>Median time from Case Notification to Complete Facility</th>
                <th>Median time from Complete Facility to Complete Household</th>
                <th>Median time from SMS sent to Complete Household</th>
              </thead>
              <tbody>
                #{
                  _(usersView.rows).map (user) ->
                    "
                    <tr id='#{user.id.replace(/user\./,"")}'>
                      <td>#{user.value[0] or user.value[1]}</td>
                      <td>#{user.key or "-"}</td>
                    </tr>
                    "
                  .join("")
                }
              </tbody>
            </table>
          </div>
        "

        medianTime = (values)=>
          values = _(values).compact()
          values = values.sort( (a,b) -> b-a)
          half = Math.floor values.length/2
          if values.length % 2
            return values[half]
          else
            return (values[half-1] + values[half]) / 2.0

        medianTimeFormatted = (times) ->
          duration = moment.duration(medianTime(times))
          if duration.seconds() is 0
            return "-"
          else
            return duration.humanize()

        averageTime = (times) ->
          sum = 0
          amount = 0
          _(times).each (time) ->
            if time?
              amount += 1
              sum += time

          return 0 if amount is 0
          return sum/amount

        averageTimeFormatted = (times) ->
          duration = moment.duration(averageTime(times))
          if duration.seconds() is 0
            return "-"
          else
            return duration.humanize()

        # Initialize the dataByUser object
        dataByUser = {}
        _(usersView.rows).each (user) ->
          dataByUser[user.id.replace(/user\./,"")] = {
            userId: user.id.replace(/user\./,"")
            caseIds: {}
            cases: {}
            casesWithoutCompleteHousehold: {}
            casesWithCompleteHousehold: {}
            timesFromSMSToCaseNotification: []
            timesFromCaseNotificationToCompleteFacility: []
            timesFromFacilityToCompleteHousehold: []
            timesFromSMSToCompleteHousehold: []
          }

        total = {
          caseIds: {}
          cases: {}
          casesWithoutCompleteHousehold: {}
          casesWithCompleteHousehold: {}
          timesFromSMSToCaseNotification: []
          timesFromCaseNotificationToCompleteFacility: []
          timesFromFacilityToCompleteHousehold: []
          timesFromSMSToCompleteHousehold: []
        }


        # Get the the caseids for all of the results in the data range with the user id
        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByDateWithUserAndCaseId",
          startkey: @startDate
          endkey: @endDate
          include_docs: false
          success: (results) ->
            _(results.rows).each (result) ->
              caseId = result.value[1]
              user = result.value[0]
              dataByUser[user].caseIds[caseId] = true
              dataByUser[user].cases[caseId] = {}
              total.caseIds[caseId] = true
              total.cases[caseId] = {}

            addDataTables = _.after _(dataByUser).size() , () ->
              $("#usersReport").dataTable
                aoColumnDefs: [
                  "sType": "humanduration"
                  "aTargets": [8,9,10,11]
                ]
                aaSorting: [[4,"desc"],[3,"desc"]]
                iDisplayLength: 50

              _(total).each (value,key) ->
                if key is "caseIds"
                  ""
                else if key is "cases" or key is "casesWithoutCompleteHousehold" or key is "casesWithCompleteHousehold"
                  $("tr##{key}").append "<td>#{_(value).size()}</td>"
                else
                  $("tr##{key}").append "<td>#{value}</td>"

            # Process the case data for each user then put it into the table
            _(dataByUser).each (userData,user) ->
              if _(dataByUser[user].cases).size() is 0
                $("tr##{user}").hide()

              # Get the time differences within each case
              caseIds = _(userData.cases).map (foo, caseId) -> caseId

              $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
                keys: caseIds
                include_docs: true
                error: (error) ->
                  console.error "Error finding cases: " + JSON.stringify error
                success: (result) ->
                  caseId = null
                  caseResults = []
                  # Collect all of the results for each caseid, then creeate the case and  process it
                  _.each result.rows, (row) ->
                    if caseId? and caseId isnt row.key
                      malariaCase = new Case
                        caseID: caseId
                        results: caseResults
                      caseResults = []

                      userData.cases[caseId] = malariaCase
                      userData.casesWithoutCompleteHousehold[caseId] = malariaCase unless malariaCase.followedUp()
                      userData.casesWithCompleteHousehold[caseId] = malariaCase if malariaCase.followedUp()
                      userData.timesFromSMSToCaseNotification.push malariaCase.timeFromSMStoCaseNotification()
                      userData.timesFromCaseNotificationToCompleteFacility.push malariaCase.timeFromCaseNotificationToCompleteFacility()
                      userData.timesFromFacilityToCompleteHousehold.push malariaCase.timeFromFacilityToCompleteHousehold()
                      userData.timesFromSMSToCompleteHousehold.push malariaCase.timeFromSMSToCompleteHousehold()

                      total.cases[caseId] = malariaCase
                      total.casesWithoutCompleteHousehold[caseId] = malariaCase unless malariaCase.followedUp()
                      total.casesWithCompleteHousehold[caseId] = malariaCase if malariaCase.followedUp()
                      total.timesFromSMSToCaseNotification.push malariaCase.timeFromSMStoCaseNotification()
                      total.timesFromCaseNotificationToCompleteFacility.push malariaCase.timeFromCaseNotificationToCompleteFacility()
                      total.timesFromFacilityToCompleteHousehold.push malariaCase.timeFromFacilityToCompleteHousehold()
                      total.timesFromSMSToCompleteHousehold.push malariaCase.timeFromSMSToCompleteHousehold()
                      
    
                    caseResults.push row.doc
                    caseId = row.key

                  _(userData.cases).each (results,caseId) ->
                    _(userData).extend {
                      medianTimeFromSMSToCaseNotification: medianTimeFormatted(userData.timesFromSMSToCaseNotification)
                      medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(userData.timesFromCaseNotificationToCompleteFacility)
                      medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(userData.timesFromFacilityToCompleteHousehold)
                      medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(userData.timesFromSMSToCompleteHousehold)
                    }

                  _(total).extend {
                    medianTimeFromSMSToCaseNotification: medianTimeFormatted(total.timesFromSMSToCaseNotification)
                    medianTimeFromCaseNotificationToCompleteFacility: medianTimeFormatted(total.timesFromCaseNotificationToCompleteFacility)
                    medianTimeFromFacilityToCompleteHousehold: medianTimeFormatted(total.timesFromFacilityToCompleteHousehold)
                    medianTimeFromSMSToCompleteHousehold: medianTimeFormatted(total.timesFromSMSToCompleteHousehold)
                  }


                  $("tr##{userData.userId}").append "
                    <td class='number'><button type='button' onClick='$(this).parent().next().toggle();$(\"th.cases\").toggle()'>#{_(userData.cases).size()}</button></td>
                    <td style='display:none' class='detail'>
                    #{
                      cases = _(userData.cases).keys()
                      _(cases).map (caseId) ->
                        "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                      .join(" ")
                    }
                    </td>
                    <td class='number'><button onClick='$(this).parent().next().toggle();$(\"th.casesWithoutCompleteHousehold\").toggle()' type='button'>#{_(userData.casesWithoutCompleteHousehold).size() or "-"}</button></td>
                    <td style='display:none' class='casesWithoutCompleteHousehold-detail'>
                    #{
                      cases = _(userData.casesWithoutCompleteHousehold).keys()
                      _(cases).map (caseId) ->
                        "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                      .join(" ")
                    }
                    </td>


                    <td class='number'><button onClick='$(this).parent().next().toggle();$(\"th.casesWithCompleteHousehold\").toggle()' type='button'>#{_(userData.casesWithCompleteHousehold).size() or "-"}</button></td>
                    <td style='display:none' class='casesWithCompleteHousehold-detail'>
                    #{
                      cases = _(userData.casesWithCompleteHousehold).keys()
                      _(cases).map (caseId) ->
                        "<button type='button'><a href='#show/case/#{caseId}'>#{caseId}</a></button>"
                      .join(" ")
                    }
                    </td>

                    <td class='number'>#{userData.medianTimeFromSMSToCaseNotification or "-"}</td>
                    <td class='number'>#{userData.medianTimeFromCaseNotificationToCompleteFacility or "-"}</td>
                    <td class='number'>#{userData.medianTimeFromFacilityToCompleteHousehold or "-"}</td>
                    <td class='number'>#{userData.medianTimeFromSMSToCompleteHousehold or "-"}</td>
                  "

                  addDataTables()



  locations: ->

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
              hasAdditionalPositiveCasesAtHousehold: caseResult.hasAdditionalPositiveCasesAtHousehold()
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
              "fillColor": if location.hasAdditionalPositiveCasesAtHousehold then "red" else ""
              "radius": 5
              )
              .addTo(@map)
              .bindPopup "
                 #{location.date}: <a href='#show/case/#{location.MalariaCaseID}'>#{location.MalariaCaseID}</a>
               "



  spreadsheet: ->

    $("#row-region").hide()
    $("#reportContents").html "
      <a id='csv' href='http://spreadsheet.zmcp.org/spreadsheet_cleaned/#{@startDate}/#{@endDate}'>Download spreadsheet for #{@startDate} to #{@endDate}</a>
    "
    $("a#csv").button()


  csv: ->

    question = @reportOptions.question
    questions = "USSD Notification,Case Notification,Facility,Household,Household Members".split(",")

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

            $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
              keys: _(caseIds).keys()
              include_docs: true
              error: (error) ->  console.error "Error finding cases: " + JSON.stringify error
              success: (result) ->
                # Collect all of the results for each caseid, then creeate the case and  process it
                caseId = null
                caseResults = []
                _.each result.rows, (row) ->
                  if caseId? and caseId isnt row.key
                    malariaCase = new Case
                      caseID: caseId
                      results: caseResults
                          
                    caseResults = []

                    if question?
                      $('div').append(
                        if question is "Household Members"
                          _(malariaCase.spreadsheetRow(question)).map (householdMembersRows) ->
                            result = _(householdMembersRows).map (data) ->
                              "\"#{data}\""
                            .join(",")
                            result += "--EOR--<br/>" if result isnt ""
                          .join("")
                        else
                          result = _(malariaCase.spreadsheetRow(question)).map (data) ->
                            "\"#{data}\""
                          .join(",")
                          result += "--EOR--<br/>" if result isnt ""
                      )
                    else
                      _(questions).each (question) ->
                        $("div##{question.replace(" ","")}").append(
                          if question is "Household Members"
                            _(malariaCase.spreadsheetRow(question)).map (householdMembersRows) ->
                              result = _(householdMembersRows).map (data) ->
                                "\"#{data}\""
                              .join(",")
                              result += "--EOR--<br/>" if result isnt ""
                            .join("")
                          else
                            result = _(malariaCase.spreadsheetRow(question)).map (data) ->
                              "\"#{data}\""
                            .join(",")
                            result += "--EOR--<br/>" if result isnt ""
                        )
        
                  caseResults.push row.doc
                  caseId = row.key

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
  

  createTable: (headerValues, rows, id) ->
   "
      <table #{if id? then "id=#{id}" else ""} class='tablesorter'>
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
            aggregationKey = date.clone().endOf("week").unix()
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

          results[anotherIndex] = [
            title         : "Period"
            text          :  "#{moment(options.startDate).format("YYYY-MM-DD")} -> #{moment(options.endDate).format("YYYY-MM-DD")}"
          ,
            title         : "No. of cases reported at health facilities"
            disaggregated : data.followups[district].allCases
          ,
            title         : "No. of cases reported at health facilities with complete household visits"
            disaggregated : data.followups[district].casesWithCompleteHouseholdVisit
          ,
            title         : "% of cases reported at health facilities with complete household visits"
            percent       : 1 - (data.followups[district].casesWithCompleteHouseholdVisit.length/data.followups[district].allCases.length)
          ,
            title         : "Total No. of cases (including cases not reported by facilities) with complete household visits"
            disaggregated : data.followups[district].casesWithCompleteHouseholdVisit
          ,
            title         : "No. of additional household members tested"
            disaggregated : data.passiveCases[district].householdMembers
          ,
            title         : "No. of additional household members tested positive"
            disaggregated : data.passiveCases[district].passiveCases
          ,
            title         : "% of household members tested positive"
            percent       : data.passiveCases[district].passiveCases.length / data.passiveCases[district].householdMembers.length
          ,
            title         : "% increase in cases found using MCN"
            percent       : data.passiveCases[district].passiveCases.length / data.passiveCases[district].indexCases.length
          ,
            title         : "No. of positive cases (index & household) in persons under 5"
            disaggregated : data.ages[district].underFive
          ,
            title         : "Percent of positive cases (index & household) in persons under 5"
            percent       : data.ages[district].underFive.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) with at least a facility followup"
            disaggregated : data.totalPositiveCases[district]
          ,
            title         : "Positive Cases (index & household) that slept under a net night before diagnosis (percent)"
            disaggregated : data.netsAndIRS[district].sleptUnderNet
            appendPercent : data.netsAndIRS[district].sleptUnderNet.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases from a household that has been sprayed within last #{Coconut.IRSThresholdInMonths} months"
            disaggregated : data.netsAndIRS[district].recentIRS
            appendPercent : data.netsAndIRS[district].recentIRS.length / data.totalPositiveCases[district].length
          ,
            title         : "Positive Cases (index & household) that traveled within last month (percent)"
            disaggregated : data.travel[district].travelReported
            appendPercent : data.travel[district].travelReported.length / data.totalPositiveCases[district].length
          ]

          renderTable()

  updateAnalysis: =>
    @analysis($("[name=aggregationType]:checked").val())

  analysis: (aggregationLevel = "District") ->

    $("#reportContents").html "
      <div id='analysis'>
      <hr/>
      Aggregation Type:
      <input name='aggregationType' type='radio' #{if aggregationLevel is "District" then "checked='true'" else ""} value='District'>District</input>
      <input name='aggregationType' type='radio' #{if aggregationLevel is "Shehia" then "checked='true'" else ""}  value='Shehia'>Shehia</input>
      <hr/>
      <div style='font-style:italic'>Click on a column heading to sort.</div>
      <hr/>
      </div>
    "

    reports = new Reports()
    reports.casesAggregatedForAnalysis
      aggregationLevel: aggregationLevel
      startDate: @startDate
      endDate: @endDate
      mostSpecificLocation: @mostSpecificLocationSelected()
      success: (data) =>


        headings = [
          aggregationLevel
          "Cases"
          "Cases missing USSD Notification"
          "Cases missing Case Notification"
          "Cases with complete facility visit"
          "Cases without complete facility visit (but with case notification)"
          "Cases with complete household visit"
          "Cases without complete household visit (but with complete facility visit)"
          "% of cases with complete household visit"
        ]

        $("#analysis").append "<h2>Cases Followed Up<small> <button onClick='$(\".details\").toggle()'>Toggle Details</button></small></h2>"
        $("#analysis").append @createTable headings, "
          #{
            _.map(data.followups, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.allCases)}</td>
                  <td class='missingUSSD details'>#{@createDisaggregatableCaseGroup(values.missingUssdNotification)}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.missingCaseNotification)}</td>
                  <td class='details'>#{@createDisaggregatableCaseGroup(values.casesWithCompleteFacilityVisit)}</td>
                  <td>#{@createDisaggregatableCaseGroup(_.difference(values.casesWithoutCompleteFacilityVisit,values.missingCaseNotification))}</td>
                  <td class='details'>#{@createDisaggregatableCaseGroup(values.casesWithCompleteHouseholdVisit)}</td>
                  <td>#{@createDisaggregatableCaseGroup(_.difference(values.casesWithoutCompleteHouseholdVisit,values.casesWithoutCompleteFacilityVisit))}</td>
                  <td>#{@formattedPercent(values.casesWithCompleteHouseholdVisit.length/values.allCases.length)}</td>
                </tr>
              "
            ).join("")
          }
        ", "cases-followed-up"

        _([
          "Cases with complete household visit"
          "Cases with complete facility visit"
          "Cases missing USSD Notification"
        ]).each (column) ->
          $("th:contains(#{column})").addClass "details"
        $(".details").hide()

        
        _.delay ->

          $("table.tablesorter").each (index,table) ->

            _($(table).find("th").length).times (columnNumber) ->
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
          $(".max-value-for-column button.same-cell-disaggregatable").css("color","red")

        ,2000


        $("#analysis").append "
          <hr>
          <h2>Household Members</h2>
        "
        $("#analysis").append @createTable "District, No. of cases followed up, No. of additional household members tested, No. of additional household members tested positive, % of household members tested positive, % increase in cases found using MCN".split(/, */), "
          #{
#            console.log (_.pluck data.passiveCases.ALL.householdMembers, "MalariaCaseID").join("\n")
            _.map(data.passiveCases, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableCaseGroup(values.indexCases)}</td>
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
          <h2>Age: <small>Includes index cases with complete household visits and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, <5, 5<15, 15<25, >=25, Unknown, Total, %<5, %5<15, %15<25, %>=25, Unknown".split(/, */), "
          #{
            _.map(data.ages, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(values.underFive.length,values.underFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fiveToFifteen.length,values.fiveToFifteen)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.fifteenToTwentyFive.length,values.fifteenToTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.overTwentyFive.length,values.overTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.unknown.length,values.overTwentyFive)}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>

                  <td>#{@formattedPercent(values.underFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.fiveToFifteen.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.fifteenToTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.overTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Gender: <small>Includes index cases with complete household visits and positive household members<small></h2>
        "
        $("#analysis").append @createTable "District, Male, Female, Unknown, Total, % Male, % Female, % Unknown".split(/, */), "
          #{
            _.map(data.gender, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(values.male.length,values.male)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.female.length,values.female)}</td>
                  <td>#{@createDisaggregatableDocGroup(values.unknown.length,values.unknown)}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>

                  <td>#{@formattedPercent(values.male.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.female.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{@formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }
        "

        $("#analysis").append "
          <hr>
          <h2>Nets and Spraying: <small>Includes index cases with complete household visits and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, Positive Cases, Positive Cases (index & household) that slept under a net night before diagnosis, %, Positive Cases from a household that has been sprayed within last #{Coconut.IRSThresholdInMonths} months, %".split(/, */), "
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
          <h2>Travel History: <small>Includes index cases with complete household visits and positive household members</small></h2>
        "
        $("#analysis").append @createTable "District, Positive Cases, Positive Cases (index & household) that traveled within last month, %".split(/, */), "
          #{
            _.map(data.travel, (values,location) =>
              "
                <tr>
                  <td>#{location}</td>
                  <td>#{@createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{@createDisaggregatableDocGroup(values.travelReported.length,values.travelReported)}</td>
                  <td>#{@formattedPercent(values.travelReported.length / data.totalPositiveCases[location].length)}</td>
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

  pilotNotifications: ->

    $("#reportContents").html "
      <h2>Comparison of Case Notifications from USSD vs Pilot at all pilot sites</h2>
      <div style='background-color:#FFCCCC'>
      Pink entires are unmatched. If they cannot be matched (due to spelling differences for instance) recommend calling facility to find out why the case was not sent with both systems.
      </div>
      <table id='comparison'>
        <thead>
          <th>Facility</th>
          <th>Patient Name</th>
          <th>USSD Case ID</th>
          <th>Pilot Case ID</th>
          <th>USSD Notification Time</th>
          <th>Pilot Notification Time</th>
          <th>Time Difference</th>
          <th class='sort'>Sorting</th>
          <th>Source</th>
        </thead>
        <tbody></tbody>
      </table>

      <h2>Pilot Weekly Reports</h2>
      <table id='weekly_report'>
        <thead></thead>
        <tbody></tbody>
      </table>

      <h2>Pilot New Cases Details</h2>
      <button onClick='$(\"#new_case\").toggle()'>Show/Hide</button>
      <table style='display:none' id='new_case'>
        <thead></thead>
        <tbody></tbody>
      </table>

    "

    comparisonData = {}

    renderComparisonData = _.after 2, ->
        $("#comparison tbody").html _.map comparisonData, (data, facilityWithPatientName) -> "
          <tr>
            <td>#{data.facility}</td>
            <td>#{data.name || "-"}</td>
            <td>#{data.USSDcaseId || "-"}</td>
            <td>#{data.pilotCaseId || "-"}</td>
            <td>#{data["USSD Notification Time"] || "-"}</td>
            <td>#{data["Pilot Notification Time"] || "-"}</td>
            <td class='difference'>
              #{
                if data["Pilot Notification Time"] and data["USSD Notification Time"]
                  moment(data["USSD Notification Time"]).from(moment(data["Pilot Notification Time"]), true)
                else
                  "-"
              }
            </td>
            <td style='display:none' class='sort'>#{data["Pilot Notification Time"] || ""}#{data["USSD Notification Time"] || ""}</td>
            <td>#{data.source || "-"}</td>
          </tr>
        "

        $(".sort").hide()

        $("#comparison").dataTable
          aaSorting: [[0,"asc"],[6,"desc"],[5,"desc"]]
          iDisplayLength: 50
        
        $(".difference:contains(-)").parent().attr("style","background-color: #FFCCCC")



    @getCases
      success: (results) =>
        pilotFacilities = [
          "CHUKWANI"
          "SELEM"
          "BUBUBU JESHINI"
          "UZINI"
          "MWERA"
          "MIWANI"
          "CHIMBA"
          "TUMBE"
          "PANDANI"
          "TUNGAMAA"
        ]
        _.each results, (caseResult) ->
          if _(pilotFacilities).contains caseResult.facility()
            facilityWithPatientName = "#{caseResult.facility()}-#{caseResult.indexCasePatientName()}"
            comparisonData[facilityWithPatientName] = {} unless comparisonData[facilityWithPatientName]?
            comparisonData[facilityWithPatientName].name = caseResult.indexCasePatientName()
            comparisonData[facilityWithPatientName].USSDcaseId = caseResult.MalariaCaseID()
            comparisonData[facilityWithPatientName].facility = caseResult.facility()
            comparisonData[facilityWithPatientName]["USSD Notification Time"] = caseResult["USSD Notification"].date if caseResult["USSD Notification"]?

        renderComparisonData()

    $("tr.location").hide()

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/pilotNotifications",
      startkey: @startDate
      endkey: moment(@endDate).endOf("day").format("YYYY-MM-DD HH:mm:ss") # include all entries for today
      include_docs: true
      success: (results) =>

        tableData = {
          new_case: ""
          weekly_report: ""
        }
        _(results.rows).each (row) =>

          facilityWithPatientName = "#{row.doc.hf}-#{row.doc.name}"
          comparisonData[facilityWithPatientName] = {} unless comparisonData[facilityWithPatientName]?
          comparisonData[facilityWithPatientName].name = row.doc.name
          comparisonData[facilityWithPatientName].pilotCaseId = row.doc.caseid
          comparisonData[facilityWithPatientName].facility = row.doc.hf
          comparisonData[facilityWithPatientName]["Pilot Notification Time"] = row.doc.date
          comparisonData[facilityWithPatientName].source = row.doc.source

          keys = _(_(row.doc).keys()).without "_id","_rev", "type"
          type = row.doc.type.replace(/\s/,"_")
          if $("##{type} thead").html() is ""
            $("##{type} thead").html _(keys).map((key) -> "<th>#{key}</th>").join ""
              
          tableData[type] += "
            <tr>
              #{
                _(keys).map (key) -> "<td>#{row.doc[key]}</td>"
                .join ""
              }
            </tr>
          "

        _(_(tableData).keys()).each (key) ->
          $("##{key} tbody").html tableData[key]

        renderComparisonData()


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
        console.log Coconut.questions
        tableColumns = tableColumns.concat Coconut.questions.map (question) ->
          question.label()
        console.log tableColumns
        _.each tableColumns, (text) ->
          $("table.summary thead tr").append "<th>#{text} (<span id='th-#{text.replace(/\s/,"")}-count'></span>)</th>"

    @getCases
      success: (cases) =>
        _.each cases, (malariaCase) =>

          $("table.summary tbody").append "
            <tr class='followed-up-#{malariaCase.followedUp()}' id='case-#{malariaCase.caseID}'>
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

  createDisaggregatableCaseGroup: (cases, text) ->
    text = cases.length unless text?
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




  systemErrors: =>
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

  casesWithoutCompleteHouseholdVisit: =>
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

  casesWithUnknownDistricts: =>
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


  tabletSync: (options) =>
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
              console.log user.get("name") if user.district()? and not (user.inactive is "true" or user.inactive)
              console.log user if user.district()? and not (user.inactive is "true" or user.inactive)
              initializeEntryForUser(user.get("_id")) if user.district()? and not (user.get("inactive") is "true" or user.get("inactive"))

            _(syncLogResult.rows).each (syncEntry) =>
              unless numberOfSyncsPerDayByUser[syncEntry.value]?
                initializeEntryForUser(syncEntry.value)
              numberOfSyncsPerDayByUser[syncEntry.value][moment(syncEntry.key).format("YYYY-MM-DD")] += 1

            console.table numberOfSyncsPerDayByUser

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
                                "#CCFFCC"
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

            $("#syncLogTable_length").hide()
            $("#syncLogTable_info").hide()
            $("#syncLogTable_paginate").hide()








  weeklyReports: (options) =>
    $("#row-region").hide()
    startDate = moment(@startDate)
    startYear = startDate.format("YYYY")
    startWeek =startDate.format("ww")
    endDate = moment(@endDate).endOf("day")
    endYear = endDate.format("YYYY")
    endWeek = endDate.format("ww")
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/weeklyDataBySubmitDate",
      startkey: [startYear,startWeek]
      endkey: [endYear,endWeek]
      include_docs: true
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
          Weekly Reports<br/>
          <br/>
          <table class='tablesorter' id='syncLogTable'>
            <thead>
              #{
                _.map results.rows[0].doc, (value,key) ->
                  console.log key
                  return if _(["_id","_rev","source","type"]).contains(key)
                  "<th>#{key}</th>"
                .join("")
              }
            </thead>
            <tbody>
              #{
                _(results.rows).map (row) ->
                  "<tr>
                    #{
                      _(row.doc).map (value,key) ->
                        return if _(["_id","_rev","source","type"]).contains(key)
                        "<td>#{value}</td>"
                      .join("")
                    }
                  </tr>"
                .join("")
              }
            </tbody>
          </table>
        "

        $("#syncLogTable").dataTable
          aaSorting: [[0,"desc"],[1,"desc"],[2,"desc"]]
          iDisplayLength: 50
