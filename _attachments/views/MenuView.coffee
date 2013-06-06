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

        @$el.find("ul").html "<li><a id='menu-retrieve-client' href=''><h2>Find/Create Client<div id='menu-partial-amount'>&nbsp;</div></h2></a></li> "
        @$el.find("ul").append(Coconut.questions.map (question,index) ->
          "<li><a id='menu-#{index}' class='menu-#{index}' href='#show/results/#{escape(question.id)}'><h2>#{question.id}<div id='menu-partial-amount'></div></h2></a></li>"
        .join(" "))
        $(".question-buttons").navbar()
        # disable form buttons
        Coconut.questions.map (question,index) -> $(".menu-#{index}").addClass('ui-disabled');
        @update()

  update: ->
    Coconut.questions.each (question,index) =>
      results = new ResultCollection()
      results.fetch
        include_docs: false
        question: question.id
        isComplete: false
        success: =>
          $("#menu-#{index} #menu-partial-amount").html results.length

    $.ajax "version",
      success: (result) ->
        $("#version").html result
      error:
        $("#version").html "-"
