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
    "change #aggregateBy": "update"
    "click #toggleDisaggregation": "toggleDisaggregation"

  update: =>
    reportOptions =
      startDate: $('#start').val()
      endDate: $('#end').val()
      reportType: $('#report-type :selected').text()
      question: $('#selected-question :selected').text()
      aggregateBy: $("#aggregateBy :selected").text()

    _.each @locationTypes, (location) ->
      reportOptions[location] = $("##{location} :selected").text()

    url = "reports/" + _.map(reportOptions, (value, key) ->
      "#{key}/#{escape(value)}"
    ).join("/")

    Coconut.router.navigate(url,true)

  render: (options) =>

    @reportType = options.reportType || "results"
    @startDate = options.startDate || moment(new Date).subtract('days',30).format("YYYY-MM-DD")
    @endDate = options.endDate || moment(new Date).format("YYYY-MM-DD")
    @question = unescape(options.question)
    @aggregateBy = options.aggregateBy || "District"

    @$el.html "
      <style>
        table.results th.header, table.results td{
          font-size:150%;
        }

      </style>

      <table id='reportOptions'></table>
    "

    Coconut.questions.fetch
      success: =>
        $("#reportOptions").append @formFilterTemplate(
          id: "question"
          label: "Question"
          form: "
              <select id='selected-question'>
                #{
                  Coconut.questions.map( (question) =>
                    "<option #{if question.label() is @question then "selected='true'" else ""}>#{question.label()}</option>"
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
              _.map(["spreadsheet","results","summarytables","confirmingNets"], (type) =>
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

  spreadsheet: =>
    @viewQuery
      success: (results) =>
        csvData = results.map( (result) ->
          _.map(results.fields, (field) ->
            result.get field
          ).join ","
        ).join "\n"

        @$el.append "
          <a id='csv' href='data:text/octet-stream;base64,#{Base64.encode(results.fields.join(",") + "\n" + csvData)}' download='#{@startDate+"-"+@endDate}.csv'>Download spreadsheet</a>
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


  confirmingNets: =>
    aggregationLevels = "Region,District,Ward,Village,Name".split(/,/)

    @$el.append  "
      <br/>
      <hr/>
      Choose a field to aggregate by:<br/>
      <select id='aggregateBy'>
        #{
          _.map aggregationLevels, (field) =>
            "<option id='#{field}' #{if @aggregateBy is field then "selected='true'" else ""}>#{field}</option>"
          .join("")
        }
      </select>
      <br/>
    "

    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/confirmingNetsResults",
      include_docs: true
      startkey: @startDate
      endkey: @endDate
      success: (result) =>

        aggregatedData = {}
        _(aggregationLevels).each (level) ->
          aggregatedData[level] = {}

        dupChecker = {}

        _(result.rows).each (row) ->

          doc = row.doc

          # Results are sorted so that most recent date is first, if a location comes up twice, always take the more recent value
          uniqueLocationString = "#{doc.Region}-#{doc.District}-#{doc.Ward}-#{doc.Village}-#{doc.Name}"
          if dupChecker[uniqueLocationString]
            return
          else
            dupChecker[uniqueLocationString] = true

          _(aggregationLevels).each (level) ->
            unless aggregatedData[level][doc[level]]?
              aggregatedData[level][doc[level]] =
                "Number of Nets": 0
                Region: doc.Region

            aggregatedData[level][doc[level]].District = doc.District if level is "District" or level is "Ward" or level is "Village" or level is "Name"
            aggregatedData[level][doc[level]].Ward = doc.Ward if level is "Ward" or level is "Village" or level is "Name"
            aggregatedData[level][doc[level]].Village = doc.Ward if level is "Village" or level is "Name"
            aggregatedData[level][doc[level]].Name = doc.Name if level is "Name"

            aggregatedData[level][doc[level]]["Number of Nets"] += parseInt doc["Number of Nets"]

        @$el.append "
          <table id='results' class='tablesorter'>
            <thead>
              #{
                # This is a crazy way to get a sample item in the hash
                firstItemInHash = _(aggregatedData[@aggregateBy]).find -> true
                headers = _(firstItemInHash).keys()
                _(headers).map (header) ->
                  "<th>#{header}</th>"
                .join ""
              }
            </thead>
            <tbody>
              #{
                _(aggregatedData[@aggregateBy]).map (result) ->
                  "
                    <tr>
                      #{
                        _(headers).map (header) ->
                          "<td>#{result["#{header}"]}</td>"
                        .join ""
                      }
                    </tr>
                  "
                .join ""
              }
            </tbody>
          </table>
        "
        $("#results").dataTable
          aaSorting: [[0,"desc"]]
          iDisplayLength: 25
          dom: 'T<"clear">lfrtip'
          tableTools:
            sSwfPath: "js-libraries/copy_csv_xls_pdf.swf"




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

