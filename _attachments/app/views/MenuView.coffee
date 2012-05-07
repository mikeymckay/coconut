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
        questionLinks = Coconut.questions.map (question) ->
            "<li><a href='#show/results/#{question.id}'><h2>#{question.id}</h2></a></li>"
        .join(" ")
        @$el.find("ul").html questionLinks
        $("#navbar").navbar()
#        $("a").button()
