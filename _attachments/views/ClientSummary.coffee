class ClientSummaryView extends Backbone.View
  el: '#content'

  render: =>
    console.log @client
    @$el.html "
      <h1>Client ##{@client.clientID}</h1>
      <table>
        #{
          {
            "HIV Status" : @client.hivStatus()
            "Last Blood Pressure" : @client.lastBloodPressure()
          }

        }
        <tr>
          <td>
            
          </td>
          <td>
          </td>
        </tr>
      </table>
      HIV Status:
      <pre>
        #{JSON.stringify @client.toJSON()}
      </pre>
    "



