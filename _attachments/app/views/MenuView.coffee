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
    if Coconut.config.local.get("mode") is "mobile"
      User.isAuthenticated
        success: () ->
          Coconut.questions.each (question,index) =>
            results = new ResultCollection()
            results.fetch
              question: question.id
              isComplete: "false"
              success: =>
                $("#menu-#{index} #menu-partial-amount").html results.length

    $.ajax "app/version",
      dataType: "text"
      success: (result) ->
        $("#version").html result
      error:
        $("#version").html "-"
