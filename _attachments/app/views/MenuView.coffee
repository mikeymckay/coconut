class MenuView extends Backbone.View

  el: '.question-buttons'

  events:
    "change" : "render"


  render: =>
    @$el.html "
      <div id='navbar' data-role='navbar'>
        <ul></ul>
      </div>
    "

    Coconut.questions.fetch
      success: =>

        @$el.find("ul").html(Coconut.questions.map (question,index) ->
          "<li><a id='menu-#{index}' href='#show/results/#{escape(question.id)}'><h2>#{question.id}<div id='menu-partial-amount'></div></h2></a></li>"
        .join(" "))
        $(".question-buttons").navbar()
        @update()

  update: ->
    Coconut.resultCollection ?= new ResultCollection()
    Coconut.resultCollection.fetch
      success: =>
        Coconut.questions.each (question,index) =>
          numberPartialResults = Coconut.resultCollection.partialResults(question.id).length
          $("#menu-#{index} #menu-partial-amount").html Coconut.resultCollection.partialResults(question.id).length

    $.couch.db(Coconut.config.database_name()).allDesignDocs
      success: (result) ->
        revision = result.rows[0]?.value.rev
        shortened_revision = revision.substring(0,revision.indexOf("-")+1) + revision.substring(revision.length-2)
        $("#version").html shortened_revision
      error:
        $("#version").html "-"
