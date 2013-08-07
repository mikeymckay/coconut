class Router extends Backbone.Router
  routes:
    "login": "login"
    "logout": "logout"
    "design": "design"
    "select": "select"

    "show/customResults/:question_id": "showCustomResults"

    "show/results/:question_id": "showResults"
    
    "new/result"                       : "newResult"
    "new/result/:question_id"          : "newResult"
    "new/result/:question_id/:options" : "newResult"
    
    "edit/result/:result_id": "editResult"
    "delete/result/:result_id": "deleteResult"
    "delete/result/:result_id/:confirmed": "deleteResult"
    "edit/resultSummary/:question_id": "editResultSummary"
    "analyze/:form_id": "analyze"
    "delete/:question_id": "deleteQuestion"
    "edit/:question_id": "editQuestion"
    "manage": "manage"
    "sync": "sync"
    "sync/send": "syncSend"
    "sync/get": "syncGet"
    "sync/send_and_get": "syncSendAndGet"
    "configure": "configure"
    "map": "map"
    "reports": "reports"
    "reports/*options": "reports"
    "dashboard": "dashboard"
    "dashboard/*options": "dashboard"
    "alerts": "alerts"
    "show/case/:caseID": "showCase"
    "users": "users"
    "messaging": "messaging"
    "help": "help"
    "summary/:client_id": "summary"
    "": "default"

  route: (route, name, callback) ->
    Backbone.history || (Backbone.history = new Backbone.History)
    if !_.isRegExp(route)
      route = this._routeToRegExp(route)
    Backbone.history.route(route, (fragment) =>
      args = this._extractParameters(route, fragment)
      callback.apply(this, args)

# Run this before
      $('#loading').slideDown()
      this.trigger.apply(this, ['route:' + name].concat(args))
# Run this after
      $('#loading').fadeOut()

    , this)

  help: ->
    @userLoggedIn
      success: ->
        Coconut.helpView ?= new HelpView()
        Coconut.helpView.render()

  users: ->
    @adminLoggedIn
      success: ->
        Coconut.usersView ?= new UsersView()
        Coconut.usersView.render()

  messaging: ->
    @adminLoggedIn
      success: ->
        Coconut.messagingView ?= new MessagingView()
        Coconut.messagingView.render()

  default: ->
    switch Coconut.config.local.get("mode")
      when "cloud"
        Coconut.router.navigate("dashboard",true)
      when "mobile"
        Coconut.router.navigate("new/result",true)

  clientLookup: ->
    Coconut.scanBarcodeView ?= new ScanBarcodeView()
    Coconut.scanBarcodeView.render()

  summary: (clientID) ->
    @userLoggedIn
      success: ->
        Coconut.clientSummary ?= new ClientSummaryView()
        Coconut.clientSummary.client = new Client
          clientID: clientID
        Coconut.clientSummary.client.fetch
          success: ->
            if Coconut.clientSummary.client.hasDemographicResult()
              Coconut.clientSummary.render()
            else
              Coconut.router.navigate("/new/result/Client Demographics/#{clientID}",true)
          error: ->
            throw "Could not fetch or create client with #{clientID}"

  userLoggedIn: (callback) ->
    User.isAuthenticated
      success: (user) ->
        callback.success(user)
      error: ->
        Coconut.loginView.callback = callback
        Coconut.loginView.render()

  adminLoggedIn: (callback) ->
    @userLoggedIn
      success: (user) ->
        if User.currentUser.isAdmin()
          callback.success(user)
      error: ->
        $("#content").html "<h2>Must be an admin user</h2>"

  logout: ->
    User.logout()
    Coconut.router.navigate("",true)


  alerts: ->
    @userLoggedIn
      success: ->
        if Coconut.config.local.mode is "mobile"
          $("#content").html "Alerts not available in mobile mode."
        else
          $("#content").html "
            <h1>Alerts</h1>
            <ul>
              <li>
                <b>Localised Epidemic</b>: More than 10 cases per square kilometer in KATI district near BAMBI shehia (map <a href='#reports/location'>Map</a>). Recommend active case detection in shehia.
              </li>
              <li>
                <b>Abnormal Data Detected</b>: Only 1 case reported in MAGHARIBI district for June 2012. Expected amount: 25. Recommend checking that malaria test kits are available at all health facilities in MAGHARIBI.
              </li>
            </ul>
          "

  reports: (options) ->
    @userLoggedIn
      success: ->
        if Coconut.config.local.mode is "mobile"
          $("#content").html "Reports not available in mobile mode."
        else
          options = options?.split(/\//)
          reportViewOptions = {}

          # Allows us to get name/value pairs from URL
          _.each options, (option,index) ->
            unless index % 2
              reportViewOptions[option] = options[index+1]

          Coconut.reportView ?= new ReportView()
          Coconut.reportView.render reportViewOptions

  dashboard: (options) ->
    @userLoggedIn
      success: ->
        if Coconut.config.local.mode is "mobile"
          $("#content").html "Reports not available in mobile mode."
        else
          options = options?.split(/\//)
          reportViewOptions = {}

          # Allows us to get name/value pairs from URL
          _.each options, (option,index) ->
            unless index % 2
              reportViewOptions[option] = options[index+1]

          console.log "ASDSA"
          Coconut.dashboardView ?= new DashboardView()
          Coconut.dashboardView.render reportViewOptions

  showCase: (caseID) ->
    @userLoggedIn
      success: ->
        Coconut.caseView ?= new CaseView()
        Coconut.caseView.case = new Case
          caseID: caseID
        Coconut.caseView.case.fetch
          success: ->
            Coconut.caseView.render()

  configure: ->
    @userLoggedIn
      success: ->
        Coconut.localConfigView ?= new LocalConfigView()
        Coconut.localConfigView.render()

  editResultSummary: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.resultSummaryEditor ?= new ResultSummaryEditorView()
        Coconut.resultSummaryEditor.question = new Question
          id: unescape(question_id)

        Coconut.resultSummaryEditor.question.fetch
          success: ->
            Coconut.resultSummaryEditor.render()

  editQuestion: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.designView ?= new DesignView()
        Coconut.designView.render()
        Coconut.designView.loadQuestion unescape(question_id)

  deleteQuestion: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.questions.get(unescape(question_id)).destroy
          success: ->
            Coconut.menuView.render()
            Coconut.router.navigate("manage",true)

  sync: (action) ->
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.render()

  # TODO refactor these to not use view - just use the sync model
  syncSend: (action) ->
    Coconut.router.navigate("",false)
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.sendToCloud
          success: ->
            Coconut.syncView.update()

  syncGet: (action) ->
    Coconut.router.navigate("",false)
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.getFromCloud()

  syncSendAndGet: (action) ->
  #  Coconut.router.navigate("",false)
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.sendAndGetFromCloud
          success: ->
            _.delay( ->
              Coconut.router.navigate("",false)
              document.location.reload()
            , 1000)

  manage: ->
    @adminLoggedIn
      success: ->
        Coconut.manageView ?= new ManageView()
        Coconut.manageView.render()


  newResult: (question_id, s_options = '') ->

    quid = unescape question_id

    standard_values = {}
    s_options.replace(/([^=&]+)=([^&]*)/g, (m, key, value) -> standard_values[key] = value)
    standard_values['question'] = quid

    question = new Question "id" : quid
    question.fetch
      success: ->
        Coconut.questionView = new QuestionView
          standard_values : _(standard_values).omit('question')
          result          : new Result standard_values
          model           : question
        Coconut.questionView.render()


  editResult: (result_id) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()
        Coconut.questionView.readonly = false

        Coconut.questionView.result = new Result
          _id: result_id
        Coconut.questionView.result.fetch
          success: ->
            Coconut.questionView.model = new Question
              id: Coconut.questionView.result.question()
            Coconut.questionView.model.fetch
              success: ->
                Coconut.questionView.render()



  deleteResult: (result_id, confirmed) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()
        Coconut.questionView.readonly = true

        Coconut.questionView.result = new Result
          _id: result_id
        Coconut.questionView.result.fetch
          success: ->
            if confirmed is "confirmed"
              Coconut.questionView.result.destroy
                success: ->
                  Coconut.menuView.update()
                  Coconut.router.navigate("show/results/#{escape(Coconut.questionView.result.question())}",true)
            else
              Coconut.questionView.model = new Question
                id: Coconut.questionView.result.question()
              Coconut.questionView.model.fetch
                success: ->
                  Coconut.questionView.render()
                  $("#content").prepend "
                    <h2>Are you sure you want to delete this result?</h2>
                    <div id='confirm'>
                      <a href='#delete/result/#{result_id}/confirmed'>Yes</a>
                      <a href='#show/results/#{escape(Coconut.questionView.result.question())}'>Cancel</a>
                    </div>
                  "
                  $("#confirm a").button()
                  $("#content form").css
                    "background-color": "#333"
                    "margin":"50px"
                    "padding":"10px"
                  $("#content form label").css
                    "color":"white"
                    

  design: ->
    @userLoggedIn
      success: ->
        $("#content").empty()
        Coconut.designView ?= new DesignView()
        Coconut.designView.render()

  showCustomResults:(question_id) ->
    @userLoggedIn
      success: ->
        Coconut.customResultsView ?= new CustomResultsView()
        Coconut.customResultsView.question = new Question
          id: unescape(question_id)
        Coconut.customResultsView.question.fetch
          success: ->
            Coconut.customResultsView.render()

  showResults:(question_id) ->
    @userLoggedIn
      success: ->
        Coconut.resultsView ?= new ResultsView()
        Coconut.resultsView.question = new Question
          id: unescape(question_id)
        Coconut.resultsView.question.fetch
          success: ->
            Coconut.resultsView.render()

  map: () ->
    @userLoggedIn
      success: ->
        Coconut.mapView ?= new MapView()
        Coconut.mapView.render()

  startApp: ->
    Coconut.config = new Config()
    Coconut.config.fetch
      success: ->
        unless "module" is Coconut.config.local.get("mode")
          $("[data-role=footer]").html("
            <div class='question-buttons' id='bottom-menu'></div>
            <div style='padding-top:50px;padding-bottom:50px' id='footer-menu'>

              <center>
              <span style='font-size:75%;display:inline-block'>
                <span id='user'></span>
              </span>
              #{
                switch Coconut.config.local.get("mode")
                  when "cloud"
                    "
                      <a href='#login'>Login</a>
                      <a href='#logout'>Logout</a>
                      <a id='reports' href='#reports'>Reports</a>
                      <a id='manage-button' href='#manage'>Manage</a>
                      &nbsp;
                    "
                  when "mobile"
                    "
                      <a href='#sync/send_and_get'>Sync (last done: <span class='sync-sent-and-get-status'></span>)</a>
                    "
              }
              <a href='#help'>Help</a>
              <span style='font-size:75%;display:inline-block'>Version<br/><span id='version'></span></span>
              <span style='font-size:75%;display:inline-block'><br/><span id='databaseStatus'></span></span>
              </center>
              </div>
          ").navbar()
          $('#application-title').html Coconut.config.title()

        Coconut.loginView = new LoginView()
        Coconut.questions = new QuestionCollection()
        Coconut.questionView = new QuestionView()
        Coconut.menuView = new MenuView()
        Coconut.syncView = new SyncView()
        Coconut.menuView.render()
        Coconut.syncView.update()
        Backbone.history.start()
      error: ->
        Coconut.localConfigView ?= new LocalConfigView()
        Coconut.localConfigView.render()

Coconut = {}
Coconut.router = new Router()
Coconut.router.startApp()


Coconut.debug = (string) ->
  console.log string
  $("#log").append string + "<br/>"
