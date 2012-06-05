class CaseView extends Backbone.View
  el: '#content'

  render: =>
    @$el.html "
      <h1>Case ID: #{@case.MalariaCaseID()}</h1>
      <h2>Last Modified: #{@case.LastModifiedAt()}</h2>
      <h2>Questions: #{@case.Questions()}</h2>
      <pre>
      #{JSON.stringify(@case.toJSON(), null, 4)}
      </pre>
    "
