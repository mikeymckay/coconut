class MenuView extends Backbone.View

  el: '#menu'

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
        $("#navbar").navbar()
        @update()

  update: ->
    Coconut.resultCollection ?= new ResultCollection()
    Coconut.resultCollection.fetch
      success: =>
        Coconut.questions.each (question,index) =>
          numberPartialResults = Coconut.resultCollection.partialResults(question.id).length
          $("#menu-#{index} #menu-partial-amount").html Coconut.resultCollection.partialResults(question.id).length

    $.ajax "app/version",
      success: (result) ->
        $("#version").html result
      error:
        $("#version").html "-"
