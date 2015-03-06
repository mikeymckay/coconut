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

        @$el.find("ul").append "<li><a id='menu-summary' href='#summary'><h2>Summary</h2></a></li>"

        $(".question-buttons").navbar()
        @update()

  update: ->
    if Coconut.config.local.get("mode") is "mobile"
      User.isAuthenticated
        success: () ->
          Coconut.questions.each (question,index) =>

            $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByQuestionNotCompleteNotTransferredOut",
              key: question.id
              include_docs: false
              error: (result) =>
                @log "Could not retrieve list of results: #{JSON.stringify(error)}"
              success: (result) =>
                total = 0
                _(result.rows).each (row) =>
                  transferredTo = row.value
                  if transferredTo?
                    if User.currentUser.id is transferredTo
                      total += 1
                  else
                    total += 1

                $("#menu-#{index} #menu-partial-amount").html total


    $.ajax "/#{Coconut.config.database_name()}/version",
      dataType: "json"
      success: (result) ->
        $("#version").html result.version
      error:
        $("#version").html "-"


  checkReplicationStatus: =>
    return # no longer needed, since client's sync with pouchdb
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
            #console.log JSON.stringify(response)
            progress = response?[0]?.progress
            if progress
              $("#databaseStatus").html "#{progress}% Complete"
              _.delay @checkReplicationStatus,1000
            else
              $("#databaseStatus").html ""
              _.delay @checkReplicationStatus,60000
          error: (error) =>
            console.log "Could not check active_tasks: #{JSON.stringify(error)}"
            _.delay @checkReplicationStatus,60000
