class CaseView extends Backbone.View
  el: '#content'

  render: (scrollTargetID) =>
    Coconut.case = @case
    @$el.html "
      <style>
        table.tablesorter {font-size: 125%}
      </style>

      <h1>Case ID: #{@case.MalariaCaseID()}</h1>
      <h3>Last Modified: #{@case.LastModifiedAt()}</h3>
      <h3>Questions: #{@case.Questions()}</h3>
    "

    tables = [
      "USSD Notification"
      "Case Notification"
      "Facility"
      "Household"
      "Household Members"
    ]

    @mappings = {
      createdAt: "Created At"
      lastModifiedAt: "Last Modified At"
      question: "Question"
      user: "User"
      complete: "Complete"
      savedBy: "Saved By"
    }

    # USSD Notification doesn't have a mapping
    finished = _.after 4, =>
      @$el.append _.map(tables, (tableType) =>
        if @case[tableType]?
          if tableType is "Household Members"
            _.map(@case[tableType], (householdMember) =>
              @createObjectTable(tableType,householdMember)
            ).join("")
          else
            @createObjectTable(tableType,@case[tableType])
      ).join("")
      _.each $('table tr'), (row, index) ->
        $(row).addClass("odd") if index%2 is 1
      $('html, body').animate({ scrollTop: $("##{scrollTargetID}").offset().top }, 'slow') if scrollTargetID?

    _(tables).each (question) =>
      question = new Question(id: question)
      question.fetch
        success: =>
          _.extend(@mappings, question.safeLabelsToLabelsMappings())
          finished()
          


  createObjectTable: (name,object) =>
    "
      <h2 id=#{object._id}>#{name} <small><a href='#edit/result/#{object._id}'>Edit</a></small></h2>
      <table class='tablesorter'>
        <thead>
          <tr>
            <th>Field</th>
            <th>Value</th>
          </tr>
        </thead>
        <tbody>
          #{
            _.map(object, (value, field) =>
              return if "#{field}".match(/_id|_rev|collection/)
              "
                <tr>
                  <td>
                    #{
                      @mappings[field] or field
                    }
                  </td>
                  <td>#{value}</td>
                </tr>
              "
            ).join("")
          
          }
        </tbody>
      </table>
    "
