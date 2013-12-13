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

    @checkReplicationStatus()


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

    $.ajax "/#{Coconut.config.database_name()}/version",
      dataType: "json"
      success: (result) ->
        $("#version").html result.version
      error:
        $("#version").html "-"


  checkReplicationStatus: =>
    $.couch.login
      name: Coconut.config.get "local_couchdb_admin_username"
      password: Coconut.config.get "local_couchdb_admin_password"
      error: => console.log "Could not login"
      complete: =>
        $.ajax
          url: "/_active_tasks"
          dataType: 'json'
          success: (response) =>
            # This doesn't seem to work on Kindle - always get []. Works fine if I hit kindle from chrome on laptop. Go fig.
            console.log JSON.stringify(response)
            progress = response?[0]?.progress
            if progress
              $("#databaseStatus").html "#{progress}% Complete"
              _.delay @checkReplicationStatus,1000
            else
              console.log "No database status update"
              $("#databaseStatus").html ""
              _.delay @checkReplicationStatus,60000
          error: (error) =>
            console.log "Could not check active_tasks: #{JSON.stringify(error)}"
            _.delay @checkReplicationStatus,60000
