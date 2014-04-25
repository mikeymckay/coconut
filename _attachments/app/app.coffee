class Router extends Backbone.Router
  routes:
    "login": "login"
    "logout": "logout"
    "design": "design"
    "select": "select"
    "search/results": "searchResults"
    "show/results/:question_id": "showResults"
    "new/result/:question_id": "newResult"
    "show/result/:result_id": "showResult"
    "edit/result/:result_id": "editResult"
    "delete/result/:result_id": "deleteResult"
    "delete/result/:result_id/:confirmed": "deleteResult"
    "edit/resultSummary/:question_id": "editResultSummary"
    "analyze/:form_id": "analyze"
    "delete/:question_id": "deleteQuestion"
    "edit/hierarchy/:type": "editHierarchy"
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
    "show/case/:caseID/:docID": "showCase"
    "users": "users"
    "messaging": "messaging"
    "help": "help"
    "help/:helpDocument": "help"
    "clean": "clean"
#    "clean/:applyTarget": "clean"
    "clean/:startDate/:endDate": "clean"
    "csv/:question/startDate/:startDate/endDate/:endDate": "csv"
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

  userLoggedIn: (callback) ->
    User.isAuthenticated
      success: (user) ->
        callback.success(user)
      error: ->
        Coconut.loginView.callback = callback
        Coconut.loginView.render()

  csv: (question,startDate,endDate) ->
    @userLoggedIn
      success: ->
        if User.currentUser.hasRole "reports"
          csvView = new CsvView
          csvView.question = question
          csvView.startDate = endDate
          csvView.endDate = startDate
          csvView.render()

  editHierarchy: (type) ->
    @adminLoggedIn
      success: ->
        Coconut.HierarchyView = new HierarchyView()
        if type is "geo"
          Coconut.HierarchyView.class = GeoHierarchy
        else if type is "facility"
          Coconut.HierarchyView.class = FacilityHierarchy
        Coconut.HierarchyView.render()
      error: ->
        alert("#{User.currentUser} is not an admin")

  clean: (startDate,endDate,option) ->
    redirect = false
    unless startDate
      startDate = moment().subtract(3,"month").format("YYYY-MM-DD")
      redirect = true
    unless endDate
      endDate = moment().subtract(1,"month").format("YYYY-MM-DD")
      redirect = true
    Coconut.router.navigate("clean/#{startDate}/#{endDate}",true) if redirect

    @userLoggedIn
      success: ->
        Coconut.cleanView ?= new CleanView()
        Coconut.cleanView.startDate = startDate
        Coconut.cleanView.endDate = endDate

        Coconut.cleanView.render()

  help: (helpDocument) ->
    @userLoggedIn
      success: ->
        Coconut.helpView ?= new HelpView()
        if helpDocument?
          Coconut.helpView.helpDocument = helpDocument
        else
          Coconut.helpView.helpDocument = null
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

  login: ->
    Coconut.loginView.callback =
      success: ->
        Coconut.router.navigate("",true)
    Coconut.loginView.render()


  userWithRoleLoggedIn: (role,callback) ->
    @userLoggedIn
      success: (user) ->
        if user.hasRole role
          callback.success(user)
        else
          $("#content").html "<h2>User '#{user.username()}' must have role: '#{role}'</h2>"
      error: ->
        $("#content").html "<h2>User '#{user.username()}' must have role: '#{role}'</h2>"

  adminLoggedIn: (callback) ->
    @userLoggedIn
      success: (user) ->
        if user.isAdmin()
          callback.success(user)
      error: ->
        $("#content").html "<h2>Must be an admin user</h2>"

  logout: ->
    User.logout()
    Coconut.router.navigate("",true)
    document.location.reload()

  default: ->
    @userLoggedIn
      success: ->
        if User.currentUser.hasRole "reports"
          Coconut.router.navigate("reports",true)
        $("#content").html ""

  reports: (options) ->
    showReports = =>
      options = options?.split(/\//)
      reportViewOptions = {}

      # Allows us to get name/value pairs from URL
      _.each options, (option,index) ->
        unless index % 2
          reportViewOptions[option] = options[index+1]

      Coconut.reportView ?= new ReportView()
      Coconut.reportView.render reportViewOptions

    if document.location.hash is "#reports/reportType/periodSummary/alertEmail/true"
      showReports()
    else
      @userWithRoleLoggedIn "reports",
        success: ->
          showReports()

  showCase: (caseID,docID) ->
    @userLoggedIn
      success: ->
        Coconut.caseView ?= new CaseView()
        Coconut.caseView.case = new Case
          caseID: caseID
        Coconut.caseView.case.fetch
          success: ->
            Coconut.caseView.render(docID)

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
    Coconut.router.navigate("",false)
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.render()
        Coconut.syncView.sync.sendToCloud
          success: ->
            Coconut.syncView.update()
          error: ->
            Coconut.syncView.update()

  syncGet: (action) ->
    Coconut.router.navigate("",false)
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.render()
        Coconut.syncView.sync.getFromCloud()

  manage: ->
    @adminLoggedIn
      success: ->
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

  searchResults: () ->
    @userLoggedIn
      success: ->
        Coconut.searchResultsView ?= new SearchResultsView()
        Coconut.searchResultsView.render()



  showResult: (result_id) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()
        Coconut.questionView.readonly = true

        Coconut.questionView.result = new Result
          _id: result_id
        Coconut.questionView.result.fetch
          success: ->
            question = Coconut.questionView.result.question()
            if question?
              Coconut.questionView.model = new Question
                id: question
              Coconut.questionView.model.fetch
                success: ->
                  Coconut.questionView.render()
            else
              $("#content").html "
                <button id='delete' type='button'>Delete</button>
                <pre>#{JSON.stringify Coconut.questionView.result,null,2}</pre>
              "
              $("button#delete").click ->
                if confirm("Are you sure you want to delete this result?")
                  Coconut.questionView.result.destroy
                    success: ->
                      $("#content").html "Result deleted, redirecting..."
                      _.delay ->
                        Coconut.router.navigate("/",true)
                      , 2000



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
        if Coconut.config.local.get("mode") is "cloud"
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

      error: ->
        Coconut.localConfigView ?= new LocalConfigView()
        Coconut.localConfigView.render()

Coconut = {}
Coconut.router = new Router()
Coconut.router.startApp()

Coconut.debug = (string) ->
  console.log string
  $("#log").append string + "<br/>"

Coconut.identifyingAttributes = [
  "Name"
  "name"
  "FirstName"
  "MiddleName"
  "LastName"
  "ContactMobilepatientrelative"
  "HeadofHouseholdName"
  "ShehaMjumbe"
]

Coconut.IRSThresholdInMonths = 6
