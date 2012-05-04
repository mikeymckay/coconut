class ManageView extends Backbone.View

  el: '#content'

  render: =>
    @$el.html "
      <a href='#sync'>Sync</a>
      <a href='#configure'>Configure</a>
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
    "
    Coconut.questions.fetch
      success: ->
        Coconut.questions.each (question) ->
          $("tbody").append "
            <tr>
              <td>#{question.id}</td>
              <td><a href='#edit/#{question.id}'>edit</a></td>
              <td><a href='#delete/#{question.id}'>delete</a></td>
              <td><a href='#edit/resultSummary/#{question.id}'>summary</a></td>
            </tr>
          "
