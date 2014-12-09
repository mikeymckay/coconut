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
            _.map(["spreadsheet","users"], (type) =>
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

  spreadsheet: ->

    $($("#reportOptions tr")[0]).hide()
    $("#reportOptions").after "
      <a id='csv' href='http://spreadsheet.coconutclinic.org/spreadsheet/#{@startDate}/#{@endDate}'>Download spreadsheet for #{@startDate} to #{@endDate}</a>
    "
    $("a#csv").button()

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
            

  toggleDisaggregation: ->
    $(".dissaggregatedResults").toggle()
