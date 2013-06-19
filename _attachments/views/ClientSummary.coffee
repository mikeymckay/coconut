class ClientSummaryView extends Backbone.View
  el: '#content'

  render: =>
    console.log @client
    @$el.html "
      <h1>Client #{@client.clientID}</h1>
      <a href='#new/result/Clinical%20Visit/#{@client.clientID}'><button>New clinical visit for #{@client.clientID}</button></a><br/>
      <table>
        #{
          data = {
            "Initial Visit Date" : @client.initialVisitDate()
            "Age" : @client.currentAge()
            "HIV Status" : @client.hivStatus()
            "On ART" : @client.onArt()
            "Last Blood Pressure" : @client.lastBloodPressure()
            "Allergies" : @client.allergies()
            "Complaints at Previous Visit" : @client.complaintsAtPreviousVisit()
            "Treatment Given at Previous Visit" : @client.treatmentGivenAtPreviousVIsit()
          }
          _.map(data, (value, property) ->
            "
              <tr>
                <td>
                  #{property}
                </td>
                <td>
                  #{value}
                </td>
              </tr>
            "
          ).join("")
        }
      </table>
      <h2>Previous Visit Data</h2>
      <br/>
      #{
        # TODO sort these by date
        _.map(@client.clientResults, (result) =>
          date = result.createdAt || result.VisitDate || result.fDate
          question = result.question || result.source
          id = result._id || ""
          "
          #{question}: #{date}
          <button onClick='$(\"#result-#{id}\").toggle()' type='button'>View</button>
          #{if result.question? then "<a href='#edit/result/#{id}'><button>Edit</button></a>" else ""}
          <div id='result-#{id}' style='display: none'>
            #{@renderResult(result)}
          </div>
          "
        ).join("")
      }
    "
    $("button").button()

  renderResult: (result) =>
    "
      <pre style='font-size:50%'>
#{JSON.stringify result, undefined, 2}
      </pre>
    "
