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

    @updateVersion()
    @checkReplicationStatus()

    Coconut.questions.fetch
      include_docs: true
      success: =>

        @$el.find("ul").html "
          <li>
            <a id='menu-retrieve-client' href='#new/result'>
              <h2>Find/Create Client<div id='menu-partial-amount'>&nbsp;</div></h2>
            </a>
          </li> "
        @$el.find("ul").append(Coconut.questions.map (question,index) ->
          "<li data-question-name='#{question.label()}'>
            <a id='menu-#{index}' class='menu-#{index}' href='#show/results/#{escape(question.id)}'>
              <h2>#{question.id}
                <small>
                <div id='current-user-results-today'></div>
                <div id='current-user-results'></div>
                <div id='total-user-results'></div>
                </small>
              </h2>
            </a>
          </li>"
        .join(" "))
        $(".question-buttons").navbar()
        # disable form buttons
        Coconut.questions.each (question,index) -> $(".menu-#{index}").addClass('ui-disabled')
        @update()

  updateVersion: ->
    $.ajax "version",
      success: (result) ->
        $("#version").html result
      error:
        $("#version").html "-"

  update: ->
    @updateVersion()
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByUser",
      group: true
      success: (result) ->
        resultHash = {}
        _(result.rows).each (row) ->
          resultHash[row.key[0]] = {} unless resultHash[row.key[0]]
          resultHash[row.key[0]][row.key[1]] = row.value

          resultHash.total = {} unless resultHash.total
          resultHash.total[row.key[1]] = 0 unless resultHash.total[row.key[1]]
          resultHash.total[row.key[1]] += row.value

        Coconut.questions.each (question) ->
          $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/resultsByUser",
            key: [User.currentUser.username(),question.label()]
            reduce: false
            success: (result) ->
              _(result.rows).each (row) ->
                resultHash["today"] = {} unless resultHash["today"]
                resultHash["today"][question.label()] = 0 unless resultHash["today"][question.label()]
                console.log moment(row.value).dayOfYear()
                console.log moment().dayOfYear()
                resultHash["today"][question.label()] += 1 if moment(row.value).dayOfYear() is moment().dayOfYear()

              if User.currentUser?
                $("[data-question-name='#{question.label()}'] #current-user-results-today").html "
                  today: #{resultHash["today"][question.label()]}
                "
                $("[data-question-name='#{question.label()}'] #current-user-results").html "
                  total: #{resultHash[User.currentUser.username()][question.label()]}
                "
              $("[data-question-name='#{question.label()}'] #total-user-results").html "
                all users: #{resultHash.total[question.label()]}
              "

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
            progress = response?[0]?.progress
            if progress
              activity = if response?[0]?.target?.match(/http/) then "Sending" else if response?[0]?.source?.match(/http/) then "Receiving" else if response?[0]?.type?.match(/indexer/) then "Indexing" else "Other"
              $("#databaseStatus").html "#{activity} #{progress}% Complete"
              _.delay @checkReplicationStatus,1000
            else
              console.log "No database status update"
              $("#databaseStatus").html ""
              _.delay @checkReplicationStatus,60000
          error: (error) =>
            console.log "Could not check active_tasks: #{JSON.stringify(error)}"
            _.delay @checkReplicationStatus,60000
