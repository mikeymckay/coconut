class ReportView extends Backbone.View
  initialize: ->
    $("html").append "
      <link href='js-libraries/Leaflet/leaflet.css' type='text/css' rel='stylesheet' />
      <script type='text/javascript' src='js-libraries/Leaflet/leaflet.js'></script>
    "

  el: '#content'

  events:
    "change #reportOptions": "update"

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
    @locationTypes = "region, district, constituan, ward".split(/, /)

    _.each (@locationTypes), (option) ->
      this[option] = unescape(options[option]) || "ALL"
    @reportType = options.reportType || "locations"
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

   
    selectedLocations = {}
    _.each @locationTypes, (locationType) ->
      selectedLocations[locationType] = this[locationType]

    _.each @locationTypes, (locationType,index) =>

      $("#reportOptions").append @formFilterTemplate(
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
          _.map(["locations","spreadsheet","results"], (type) =>
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
            if locationType is "ward" and location is key
              return _.keys value
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
    @$el.append "
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

        @$el.append "
          <a id='csv' href='data:text/octet-stream;base64,#{Base64.encode(csvHeaders + "\n" + csvData)}' download='#{@startDate+"-"+@endDate}.csv'>Download spreadsheet</a>
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
