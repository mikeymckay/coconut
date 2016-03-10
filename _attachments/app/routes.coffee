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
    "edit/rainfallStations": "editRainfallStations"
    "edit/hierarchy/geo": "editGeoHierarchy"
    "edit/hierarchy/facility": "editFacilityHierarchy"
    "edit/:question_id": "editQuestion"
    "show/reportsForSending": "showReportsForSending"
    "edit/reportForSending/:reportForSendingId": "editReportForSending"
    "new/reportForSending": "editReportForSending"
    "manage": "manage"
    "sync": "sync"
    "sync/send": "syncSend"
    "sync/get": "syncGet"
    "configure": "configure"
    "map": "map"
    "reports": "reports"
    "reports/*options": "reports"
    "summary": "summary"
    "transfer/:caseID": "transfer"
    "show/case/:caseID": "showCase"
    "show/case/:caseID/:docID": "showCase"
    "show/issue/:issueID": "showIssue"
    "new/issue": "newIssue"
    "show/weeklyReport/:reportId": "showWeeklyReport"
    "users": "users"
    "messaging": "messaging"
    "help": "help"
    "help/:helpDocument": "help"
    "clean": "clean"
    "clean/:startDate/:endDate": "clean"
    "csv/:question/startDate/:startDate/endDate/:endDate": "csv"
    "raw/userAnalysis/:startDate/:endDate": "rawUserAnalysis"
    "edit/data/:document_type" : "editData"
    "parse/csv/:document_id": "parseCsv"
    "_update/Issues" : "updateIssues"
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

  rawUserAnalysis: (startDate,endDate) ->
    $("body").html ""
    Reports.userAnalysis
      usernames:  Users.map (user) -> user.username()
      startDate: startDate
      endDate: endDate
      success: (result) ->
        $("body").html "
          <span id='json'>#{JSON.stringify(result)}</span>
        "

  updateIssues: ->
    @userLoggedIn
      success: ->
        Issues.updateEpidemicAlertsForLastMonth
          success: (result) ->
            $('body').html result

  csv: (question,startDate,endDate) ->
    @userLoggedIn
      success: ->
        if User.currentUser.hasRole "reports"
          csvView = new CsvView
          csvView.question = question
          csvView.startDate = endDate
          csvView.endDate = startDate
          csvView.render()

  showReportsForSending: () ->
    @adminLoggedIn
      error: ->
        alert("#{User.currentUser} is not an admin")
      success: ->
        Coconut.reportsForSendingView = new ReportsForSendingView() unless Coconut.reportsForSendingView
        Coconut.database.allDocs
          startkey: "reportForSending"
          endkey: "reportForSending\uf000"
          include_docs: true
          error: (error) -> console.error error
          success: (result) ->
            Coconut.reportsForSendingView.reportsForSending = _(result.rows).pluck "doc"
            Coconut.reportsForSendingView.render()

  editReportForSending: (reportForSendingId) ->
    console.log reportForSendingId
    @adminLoggedIn
      error: ->
        alert("#{User.currentUser} is not an admin")
      success: ->
        Coconut.reportForSendingView = new ReportForSendingView() unless Coconut.reportForSendingView
        if reportForSendingId
          Coconut.database.openDoc reportForSendingId,
            error: (error) -> console.error error
            success: (reportForSending) ->
              Coconut.reportForSendingView.reportForSending = reportForSending
              Coconut.reportForSendingView.render()
        else
          Coconut.reportForSendingView.reportForSending = null
          Coconut.reportForSendingView.render()

  editRainfallStations: () ->
    @adminLoggedIn
      error: ->
        alert("#{User.currentUser} is not an admin")
      success: ->
        Coconut.JsonDataAsTableView = new JsonDataAsTableView() unless Coconut.JsonDataAsTableView
        Coconut.JsonDataAsTableView.fields = "Region,District,Name,Phone Numbers".split(/,/)
        Coconut.JsonDataAsTableView.name = "Rainfall Stations"
        Coconut.JsonDataAsTableView.document_id = "Rainfall Stations"
        Coconut.JsonDataAsTableView.dataToColumns = (jsonData) ->
          data = {}
          _(jsonData.data).each (stationData,stationName) =>
            _(@fields).each (field) =>
              data[stationName] = {} unless data[stationName]?
              data[stationName][field] = stationData[field]
            data[stationName]["Name"] = stationName
            data[stationName]["Phone Numbers"] = data[stationName]["Phone Numbers"].join(",")
          return data

        Coconut.JsonDataAsTableView.updateDatabaseDoc = (tableData) ->
          @databaseDoc.data = {}
          _(tableData).each (row) =>
            @databaseDoc.data[row[2]] = {
              Region: row[0]
              District: row[1]
              "Phone Numbers": row[3].split(",")
            }


        Coconut.JsonDataAsTableView.render()

  editGeoHierarchy: () ->
    @adminLoggedIn
      error: ->
        alert("#{User.currentUser} is not an admin")
      success: ->
        Coconut.JsonDataAsTableView = new JsonDataAsTableView() unless Coconut.JsonDataAsTableView
        Coconut.JsonDataAsTableView.fields = "Region,District,Shehia".split(/,/)
        Coconut.JsonDataAsTableView.name = "Regions, Districts & Shehias"
        Coconut.JsonDataAsTableView.document_id = "Geo Hierarchy"
        Coconut.JsonDataAsTableView.dataToColumns = (jsonData) ->
          data = {}
          _(jsonData.hierarchy).each (districtData,region) ->
            _(districtData).each (shehias,district) ->
              _(shehias).each (shehia) ->
                uniqueKey = "#{district}-#{shehia}"
                data[uniqueKey] =
                  Region: region
                  District: district
                  Shehia: shehia
          return data

        Coconut.JsonDataAsTableView.updateDatabaseDoc = (tableData) ->
          @databaseDoc.hierarchy = {}
          _(tableData).each (row) =>
            [region, district, shehia] = _(row).map (element) -> element.toUpperCase()
            @databaseDoc.hierarchy[region] = {} unless @databaseDoc.hierarchy[region]
            @databaseDoc.hierarchy[region][district] = [] unless @databaseDoc.hierarchy[region][district]
            @databaseDoc.hierarchy[region][district].push shehia

        Coconut.JsonDataAsTableView.render()

  editFacilityHierarchy: () ->
    @adminLoggedIn
      error: ->
        alert("#{User.currentUser} is not an admin")
      success: ->
        Coconut.JsonDataAsTableView = new JsonDataAsTableView() unless Coconut.JsonDataAsTableView
        Coconut.JsonDataAsTableView.fields = "Region,District,Facility Name,Aliases,Phone Numbers,Type".split(/,/)
        Coconut.JsonDataAsTableView.name = "Health Facilities"
        Coconut.JsonDataAsTableView.document_id = "Facility Hierarchy"
        Coconut.JsonDataAsTableView.dataToColumns = (jsonData) ->
          data = {}
          _(jsonData.hierarchy).each (facilities,district) =>
            _(facilities).each (facility) ->
              uniqueKey = "#{district}-#{facility.facility}"
              districtData = GeoHierarchy.findFirst(district,"district")
              region = if districtData then districtData.REGION else null
              data[uniqueKey] =
                Region: region
                District: district
                "Facility Name": facility.facility
                "Phone Numbers": (if facility.mobile_numbers then facility.mobile_numbers.join(" ") else "")
                "Aliases": (if facility.aliases then facility.aliases.join(", ") else "")
                Type: facility.type or ""
          return data

        Coconut.JsonDataAsTableView.updateDatabaseDoc = (tableData) ->
          @databaseDoc.hierarchy = {}
          _(tableData).each (row) =>
            [region, district, facility_name, aliases, phone_numbers, type] = row
            district = district.toUpperCase()
            facility_name = facility_name.toUpperCase()
            @databaseDoc.hierarchy[district] = [] unless @databaseDoc.hierarchy[district]
            @databaseDoc.hierarchy[district].push
              facility: facility_name
              mobile_numbers: if phone_numbers is "" then [] else phone_numbers.split(/ +|, */)
              aliases: if aliases is "" then [] else aliases.split(/, */)
              type: type or "public"

        Coconut.JsonDataAsTableView.render()


  editData: (document_id) ->
    @adminLoggedIn
      success: ->
        Coconut.EditDataView = new EditDataView() unless Coconut.EditDataView
        $.couch.db(Coconut.config.database_name()).openDoc document_id,
          error: ->
            Coconut.EditDataView.document = {
              _id: document_id
            }
            Coconut.EditDataView.render()
          success: (result) ->
            Coconut.EditDataView.document = result
            Coconut.EditDataView.render()

      error: ->
        alert("#{User.currentUser} is not an admin")


  parseCsv: (documentId) ->
    @adminLoggedIn
      success: ->
        Coconut.ParseCsvView = new ParseCsvView() unless Coconut.ParseCsvView
        Coconut.ParseCsvView.documentId = documentId
        Coconut.ParseCsvView.parse = (csvText) ->
          # TODO replace with a proper CSV parser
          # TODO also add this to an editData route
          result = {}
          _(csvText.split(/\n/)).each (row) =>
            [week,district,alert,alarm] = row.split(/[,\t]/)
            return if week is "week" # Ignore header
            result[district] =  {} unless result[district]
            result[district][week] = {
              alert: alert
              alarm: alarm
            }
          return result
        Coconut.ParseCsvView.render()

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


  userWithRoleLoggedIn: (role,callback) =>
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
        console.log user
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
      options = _(options?.split(/\//)).map (option) -> unescape(option)
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

  summary: () ->
    @userLoggedIn
      success: ->
        Coconut.summaryView ?= new SummaryView()
        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/casesWithSummaryData",
#          startkey: moment(options.endDate).endOf("day").format(Coconut.config.get "date_format")
#          endkey: options.startDate
          descending: true
          include_docs: false
          limit: 100
          success: (result) =>
            Coconut.summaryView.render result

  transfer: (caseID) ->
    @userLoggedIn
      success: ->
        $("#content").html "
          <h2>
          Select a user to transfer #{caseID} to:
          </h2>
          <select id='users'>
            <option></option>
          </select>
          <br/>
          <button onClick='window.history.back()'>Cancel</button>
          <h3>Case Results to be transferred</h3>
          <div id='caseinfo'></div>
        "
        caseResults = []

        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/cases",
          key: caseID
          include_docs: true
          error: (error) =>
            console.error error
          success: (result) =>
            caseResults = _.pluck(result.rows, "doc")
            $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/users",
              success: (result) ->
                $("#content select").append(_.map result.rows, (user) ->
                  return "" unless user.key?
                  "<option id='#{user.id}'>#{user.key}   #{user.value.join("   ")}</option>"
                .join "")
            $("#caseinfo").html (_(caseResults).map (caseResult) ->
              "
                <pre>
                  #{JSON.stringify(caseResult, null, 2)}
                </pre>
              "
            .join("<br/>"))
            $("select").selectmenu()
            $("button").button()

        $("select").change ->
          user = $('select').find(":selected").text()
          if confirm "Are you sure you want to transfer Case:#{caseID} to #{user}?"
            _(caseResults).each (caseResult) ->
              Coconut.debug "Marking #{caseResult._id} as transferred"
              caseResult.transferred = [] unless caseResult.transferred?
              caseResult.transferred.push {
                from: User.currentUser.get("_id")
                to: $('select').find(":selected").attr "id"
                time: moment().format("YYYY-MM-DD HH:mm")
                notifiedViaSms: []
                received: false
              }
            $.couch.db(Coconut.config.database_name()).bulkSave {docs: caseResults},
              error: (error) => Coconut.debug "Could not save #{JSON.stringify caseResults}: #{JSON.stringify(error)}"
              success: =>
                Coconut.router.navigate("sync/send",true)

  showCase: (caseID,docID) ->
    @userLoggedIn
      success: ->
        Coconut.caseView ?= new CaseView()
        Coconut.caseView.case = new Case
          caseID: caseID
        Coconut.caseView.case.fetch
          success: ->
            Coconut.caseView.render(docID)

  showIssue: (issueID) ->
    @userLoggedIn
      success: ->
        Coconut.issueView ?= new IssueView()
        Coconut.database.openDoc issueID,
          error: (error) -> console.error error
          success: (result) ->
            Coconut.issueView.issue = result
            Coconut.issueView.render()

  newIssue: (issueID) ->
    @userLoggedIn
      success: ->
        Coconut.issueView ?= new IssueView()
        Coconut.issueView.issue = null
        Coconut.issueView.render()

  showWeeklyReport: (reportID) ->
    @userLoggedIn
      success: ->
        Coconut.weeklyReportView ?= new WeeklyReportView()
        Coconut.database.openDoc reportID,
          error: (error) -> console.error error
          success: (result) ->
            Coconut.weeklyReportView.report = result
            Coconut.weeklyReportView.render()

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
            else # Reach here for USSD Notifications
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
            question = Coconut.questionView.result.question()
            if question?
              Coconut.questionView.model = new Question
                id: question
              Coconut.questionView.model.fetch
                success: ->
                  Coconut.questionView.render()
            else # Reach here for USSD Notifications
              $("#content").html "
                <button id='delete' type='button'>Delete</button>
                <br/>
                (Editing not supported for USSD Notifications)
                <br/>
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

  deleteResult: (result_id, confirmed) ->
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
              if confirmed is "confirmed"
                Coconut.questionView.result.destroy
                  success: ->
                    Coconut.menuView.update()
                    Coconut.router.navigate("show/results/#{escape(Coconut.questionView.result.question())}",true)
              else
                Coconut.questionView.model = new Question
                  id: question
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
            else
              Coconut.router.navigate("edit/result/#{result_id}",true)

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


