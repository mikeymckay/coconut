class Router extends Backbone.Router
  routes:
    "login": "login"
    "logout": "logout"
    "design": "design"
    "select": "select"
    "show/results/:question_id": "showResults"
    "new/result/:question_id": "newResult"
    "edit/result/:result_id": "editResult"
    "edit/resultSummary/:question_id": "editResultSummary"
    "analyze/:form_id": "analyze"
    "delete/:question_id": "deleteQuestion"
    "edit/:question_id": "editQuestion"
    "manage": "manage"
    "sync": "sync"
    "sync/send": "syncSend"
    "sync/get": "syncGet"
    "configure": "configure"
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
    if $.cookie('current_user')
      user = new User
        _id: "user.#{$.cookie('current_user')}"
      user.fetch
        success: ->
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
          id: question_id

        Coconut.resultSummaryEditor.question.fetch
          success: ->
            Coconut.resultSummaryEditor.render()

  editQuestion: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.designView ?= new DesignView()
        Coconut.designView.render()
        Coconut.designView.loadQuestion question_id

  deleteQuestion: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.questions.get(question_id).destroy
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
            Coconut.syncView.render()

  syncGet: (action) ->
    @userLoggedIn
      success: ->
        Coconut.syncView ?= new SyncView()
        Coconut.syncView.sync.getFromCloud
          success: ->
            Coconut.syncView.render()

  manage: ->
    @userLoggedIn
      success: ->
        Coconut.manageView ?= new ManageView()
        Coconut.manageView.render()


  newResult: (question_id) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()
        Coconut.questionView.result = new Result
          question: question_id
        Coconut.questionView.model = new Question {id: question_id}
        Coconut.questionView.model.fetch
          success: ->
            Coconut.questionView.render()

  editResult: (result_id) ->
    @userLoggedIn
      success: ->
        Coconut.questionView ?= new QuestionView()

        Coconut.questionView.result = new Result
          _id: result_id
        Coconut.questionView.result.fetch
          success: ->
            Coconut.questionView.model = new Question
              id: Coconut.questionView.result.question()
            Coconut.questionView.model.fetch
              success: ->
                Coconut.questionView.render()

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
          id: question_id
        Coconut.resultsView.question.fetch
          success: ->
            Coconut.resultsView.render()

  startApp: ->
    Coconut.config = new Config()
    Coconut.config.fetch
      success: ->
        $('#application-title').html Coconut.config.title()
        Coconut.loginView = new LoginView()
        Coconut.questions = new QuestionCollection()
        Coconut.questionView = new QuestionView()
        Coconut.todoView = new TodoView()
        Coconut.menuView = new MenuView()
        Coconut.menuView.render()
        Backbone.history.start()
      error: ->
        Coconut.localConfigView ?= new LocalConfigView()
        Coconut.localConfigView.render()

Coconut = {}
Coconut.router = new Router()
Coconut.router.startApp()
