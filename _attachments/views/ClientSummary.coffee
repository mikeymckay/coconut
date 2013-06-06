class ClientSummaryView extends Backbone.View
  el: '#content'

  render: =>
    console.log @client
    @$el.html "
      <h1>Client #{@client.clientID}</h1>
      <table>
        #{
          data = {
            "Initial Visit Date" : @client.initialVisitDate()
            "Age" : ""
            "HIV Status" : @client.hivStatus()
            "On ART" : ""
            "Last Blood Pressure" : @client.lastBloodPressure()
            "Allergies" : ""
            "Complaints at Previous Visit" : ""
            "Treatment Given at Previous Visit" : ""
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
      <a href='#new/result/Clinical%20Visit/#{@client.clientID}'><button>New clinical visit for #{@client.clientID}</button></a><br/>
      <a href='#'><button>Another client</button></a>
      <br/>
      <pre style='font-size:50%'>
#{JSON.stringify @client.toJSON(), undefined, 2}
      </pre>
    "
    $("button").button()
