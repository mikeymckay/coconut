class Router extends Backbone.Router
  routes:
    "login": "login"
    "logout": "logout"
    "design": "design"
    "select": "select"
    "show/results/:question_id": "showResults"
    "new/result/:question_id": "newResult"
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
    "configure": "configure"
    "map": "map"
    "reports": "reports"
    "reports/*options": "reports"
    "alerts": "alerts"
    "show/case/:caseID": "showCase"
    "users": "users"
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

  users: (userid) ->
    @userLoggedIn
      success: ->
        return unless $.cookie('current_user') is "admin"
        Coconut.usersView ?= new UsersView()
        Coconut.usersView.render()

  userLoggedIn: (callback) ->
    if $.cookie('current_user')
      user = new User
        _id: "user.#{$.cookie('current_user')}"
      user.fetch
        success: ->
          $("#user").html $.cookie('current_user')
          callback.success()
          return
        error: ->
          Coconut.loginView.callback = callback
          Coconut.loginView.render()
    else
      Coconut.loginView.callback = callback
      Coconut.loginView.render()

  logout: ->
    Coconut.router.navigate("",true)
    $.cookie('current_user',null)

  default: ->
    @userLoggedIn
      success: ->
        $("#content").html ""

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

  syncSend: (action) ->
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.sendToCloud
          success: ->
            Coconut.syncView.update()

  syncGet: (action) ->
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.getFromCloud
          success: ->
            Coconut.menuView.update()
            Coconut.syncView.update()

  manage: ->
    @userLoggedIn
      success: ->
        return unless $.cookie('current_user') is "admin"
        Coconut.manageView ?= new ManageView()
        Coconut.manageView.render()

  newResult: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()
        Coconut.questionView.result = new Result
          question: unescape(question_id)
        Coconut.questionView.model = new Question {id: unescape(question_id)}
        Coconut.questionView.model.fetch
          success: ->
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
        $("[data-role=footer]").html "
          User: <span id='user'></span>
          <a href='#logout'>Logout</a>
          District: <a href='#configure'><span id='district'></span></a>
          <a id='manage-button' style='display:none' href='#manage'>Manage</a>
          &nbsp;
          <a href='#sync/send'>Send data (last done: <span class='sync-last-time-sent'></span>)</a>
          <a href='#sync/get'>Get data (last done: <span class='sync-last-time-got'></span>)</a>
          <small>Version: <span id='version'></span></small>
        "
        $("[data-role=footer]").navbar()
        $('#application-title').html Coconut.config.title()
        $('#district').html Coconut.config.local.get "district"
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
