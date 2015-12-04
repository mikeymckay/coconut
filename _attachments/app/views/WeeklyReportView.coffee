class WeeklyReportView extends Backbone.View
  el: '#content'

  render: =>
    @$el.html "
      <h1>Weekly Report: #{@report.Year}-#{@report.Week}, District #{@report.District}, Facility #{@report.Facility}</h1>

      <pre>
      #{
        JSON.stringify(@report, null, 2).replace("{","").replace("}","").replace(/\"/g,"")
      }
      </pre>
    "
