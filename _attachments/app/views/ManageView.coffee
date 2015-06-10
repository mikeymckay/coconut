class ManageView extends Backbone.View

  el: '#content'

  render: =>
    @$el.html "
      <h1>Manage</h1>
      <!--
      <a href='#sync'>Sync</a>
      <a href='#configure'>Set cloud vs mobile</a>
      <a href='#configure'>Set location</a>
      -->
      <a href='#users'>Users</a>
      <a href='#edit/hierarchy/geo'>Shehias</a>
      <a href='#edit/hierarchy/facility'>Facilities and Facility Mobile Numbers</a>
      <a href='#edit/rainfallStations'>Rainfall Stations</a>
      <a href='#edit/data/shehias_received_irs'>Shehias received IRS</a>
      <a href='#edit/data/shehias_high_risk'>Shehias high risk</a>
      <a href='#messaging'>Send SMS to users</a>
      <!--
      <h2>Question Sets</h2>
      <a href='#design'>New</a>
      <table>
        <thead>
          <th></th>
          <th></th>
          <th></th>
          <th></th>
        </thead>
        <tbody>
        </tbody>
      </table>
      -->
    "
    $("a").button()
#    Coconut.questions.fetch
#      success: ->
#        Coconut.questions.each (question) ->
#          questionName = question.id
#          questionId = escape(question.id)
#          $("tbody").append "
#            <tr>
#              <td>#{questionName}</td>
#              <td><a href='#edit/#{questionId}'>edit</a></td>
#              <td><a href='#delete/#{questionId}'>delete</a></td>
#              <td><a href='#edit/resultSummary/#{questionId}'>summary</a></td>
#            </tr>
#          "
#        $("table a").button()
