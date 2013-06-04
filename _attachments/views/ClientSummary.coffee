class ClientSummaryView extends Backbone.View
  el: '#content'

  render: =>
    console.log @client
    @$el.html "
      <h1>Client ##{@client.clientID}</h1>
      <table>
        #{
          data = {
            "HIV Status" : @client.hivStatus()
            "Last Blood Pressure" : @client.lastBloodPressure()
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
      <pre>
#{JSON.stringify @client.toJSON(), undefined, 2}
      </pre>
    "



