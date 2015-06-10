### START THE APP ###

Coconut.router = new Router()

Coconut.config = new Config()
Coconut.config.fetch
  error: ->
    console.log "Error loading configuration file"
    $("body").append "Error loading configuration file"
  success: ->
    Coconut.database = $.couch.db(Coconut.config.database_name())
    if Coconut.config.local.get("mode") is "cloud"
      $("body").append "<script src='http://maps.google.com/maps/api/js?v=3&sensor=false'></script>"
      $("body").append "
        <style>
          .leaflet-map-pane {
                z-index: 2 !important;
          }
          .leaflet-google-layer {
                z-index: 1 !important;
          }
        </style>
      "
    $("#footer-menu").html "
      <center>
      <span style='font-size:75%;display:inline-block'>
        <span id='district'></span><br/>
        <span id='user'></span>
      </span>
      <a href='#login'>Login</a>
      <a href='#logout'>Logout</a>
      #{
      if Coconut.config.local.get("mode") is "cloud"
        "<a id='reports-button' href='#reports'>Reports</a>"
      else
        onOffline = (event) ->
          alert("offline")
        onOnline = (event) ->
          alert("online")
        document.addEventListener("offline", onOffline, false)
        document.addEventListener("online", onOnline, false)

        "
          <a href='#sync/send'>Send data (last success: <span class='sync-sent-status'></span>)</a>
          <a href='#sync/get'>Get data (last success: <span class='sync-get-status'></span>)</a>
        "
      }
      &nbsp;
      <a id='manage-button' style='display:none' href='#manage'>Manage</a>
      &nbsp;
      <a href='#help'>Help</a>
      <span style='font-size:75%;display:inline-block'>Version<br/><span id='version'></span></span>
      <span style='font-size:75%;display:inline-block'><br/><span id='databaseStatus'></span></span>
      </center>
    "
    $("[data-role=footer]").navbar()
    $('#application-title').html Coconut.config.title()

    # Only start app after Geo/Facility data has been loaded

    _(["shehias_high_risk","shehias_received_irs"]).each (docId) ->
      $.couch.db("zanzibar").openDoc docId,
        error: (error) -> console.error JSON.stringify error
        success: (result) ->
          Coconut[docId] = result

    classesToLoad = [FacilityHierarchy, GeoHierarchy]

    startApplication = _.after classesToLoad.length, ->
      Coconut.loginView = new LoginView()
      Coconut.questions = new QuestionCollection()
      Coconut.questionView = new QuestionView()
      Coconut.menuView = new MenuView()
      Coconut.syncView = new SyncView()
      Coconut.menuView.render()
      Coconut.syncView.update()
      Backbone.history.start()

    _.each classesToLoad, (ClassToLoad) ->
      ClassToLoad.load
        success: -> startApplication()
        error: (error) ->
          alert "Could not load #{ClassToLoad}: #{error}. Recommendation: Press get data again."
          #start application even on error to enable syncing to fix problems
          startApplication()



console.log "ZZZZ"
