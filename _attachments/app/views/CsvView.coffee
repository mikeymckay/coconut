class CsvView extends Backbone.View
  el: '#content'

  viewQuery: (options) ->

    results = new ResultCollection()
    results.fetch
      question: @question
      #isComplete: true
      isComplete: "trueAndFalse"
      include_docs: true
      startTime: @startDate
      endTime: @endDate
      success: ->
        results.fields = {}
        results.each (result) ->
          _.each _.keys(result.attributes), (key) ->
            results.fields[key] = true unless _.contains ["_id","_rev","question"], key
        results.fields = _.keys(results.fields)
        options.success(results)


  render: =>
    @$el.html "Compiling CSV file."
    @viewQuery
      success: (results) =>
        csvData = results.map( (result) ->
          _.map(results.fields, (field) ->
            value = result.get field
            if value?.indexOf("\"")
              return "\"#{value.replace(/"/,"\"\"")}\""
            else if value?.indexOf(",")
              return "\"#{value}\""
            else
              return value
          ).join ","
        ).join "\n"

        @$el.html "
          <a id='csv' href='data:text/octet-stream;base64,#{Base64.encode(results.fields.join(",") + "\n" + csvData)}' download='#{@question}-#{@startDate}-#{@endDate}.csv'>Download spreadsheet</a>
        "
        $("a#csv").button()
