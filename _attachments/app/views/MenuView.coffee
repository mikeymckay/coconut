class MenuView extends Backbone.View

  el: '#menu'

  render: =>
    @$el.html "
      <div id='navbar' data-role='navbar'>
        <ul></ul>
      </div>
    "

    Coconut.questions.fetch
      success: =>

        @$el.find("ul").html(Coconut.questions.map (question,index) ->
          "<li><a id='menu-#{index}' href='#show/results/#{escape(question.id)}'><h2>#{question.id}</h2></a></li>"
        .join(" "))
        $("#navbar").navbar()

        resultCollection = new ResultCollection()
        resultCollection.fetch
          success: =>
            Coconut.questions.each (question,index) =>
              numberPartialResults = resultCollection.partialResults(question.id).length
              $("#menu-#{index} h2").append "<br/>#{resultCollection.partialResults(question.id).length}"


