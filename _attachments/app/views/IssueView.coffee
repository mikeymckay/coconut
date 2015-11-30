class IssueView extends Backbone.View
  el: '#content'

  render: =>
    @$el.html "
      <h1>Issue: #{@issue.description}</h1>
      #{
        if @issue.thresholdDescription then "<h2>Threshold:#{@issue.thresholdDescription}</h2>" else ""
      }

      <ul>
        <li>Assigned To: #{@issue.assignedTo}
        <li>Date Assigned: #{@issue.dateAssigned}
        <li>Action Taken: #{@issue.actionTaken}
        <li>Solution: #{@issue.solution}
        <li>Date Resolved: #{@issue.dateResolved}
      </ul>

      <ul id='links'></ul>
    "

    if @issue.links?
      $("ul#links").append _(@issue.links).map( (link) =>
          "<li><a href='#{link}'>#{link}</li>"
      ).join("")
