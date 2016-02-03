gulp = require 'gulp'
coffee = require 'gulp-coffee'
concat = require 'gulp-concat'
uglify = require 'gulp-uglify'
cssmin = require 'gulp-cssmin'
shell = require 'gulp-shell'
gutil = require 'gulp-util'
debug = require 'gulp-debug'
sourcemaps = require 'gulp-sourcemaps'
watch = require 'gulp-watch'
livereload = require 'gulp-livereload'
_ = require 'underscore'

# CONFIGURATION #

js_library_file = "libs.min.js"
compiled_js_directory = "./_attachments/js/"
app_file = "app.min.js"
css_file = "style.min.css"
css_file_dir = "./_attachments/css/"

css_files = ("./_attachments/css/#{file}" for file in [
    "jquery.mobile-1.1.0.min.css"
    "jquery.tagit.css"
    "tablesorter.css"
    "designview.css"
    "galaxytab.css"
    "rickshaw.min.css"
    "font-awesome.min.css"
    "leaflet.css"
    "MarkerCluster.css"
    "MarkerCluster.Default.css"
    "jquery.dataTables.min.css"
    "dataTables.tableTools.min.css"
  ])

js_library_files = ("./_attachments/js-libraries/#{file}" for file in [
    "jquery-2.1.0.min.js"
    "jquery-migrate-1.2.1.min.js"
    "lodash.underscore.js"
    "backbone-min.js"
    "jquery.couch.js"
    "backbone-couchdb.js"
    "jqm-config.js"
    "jquery.mobile-1.1.0.min.js"
    "jquery.mobile.datebox.min.js"
    "jqm.autoComplete.min-1.3.js"
    "coffee-script.js"
    "typeahead.min.js"
    "handlebars.js"
    "form2js.js"
    "js2form.js"
    "jquery.toObject.js"
    "inflection.js"
    "jquery.dateFormat-1.0.js"
    "table2CSV.js"
    "jquery.tablesorter.min.js"
    "jquery.table-filter.min.js"
    "jquery.dataTables.min.js"
    "dataTables.tableTools.min.js"
    "tag-it.js"
    "moment.min.js"
    "moment-range.min.js"
    "jquery.cookie.js"
    "base64.js"
    "sha1.js"
    "d3.min.js"
    "d3.layout.min.js"
    "rickshaw.min.js"
    "latlong.js"
    "html2canvas.js"
    "markdown.min.js"
    "leaflet.js"
    "leaflet.markercluster.js"
    "leaflet-providers.js"
    "geo.js"
    "mindmup-editabletable.js"
    "underscore.string.min.js"
  ])

app_files = ("./_attachments/app/#{file}" for file in [
    'config.coffee'
    'models/Alerts.coffee'
    'models/Case.coffee'
    'models/Config.coffee'
    'models/FacilityHierarchy.coffee'
    'models/GeoHierarchy.coffee'
    'models/Help.coffee'
    'models/Issue.coffee'
    'models/Issues.coffee'
    'models/LocalConfig.coffee'
    'models/Message.coffee'
    'models/MessageCollection.coffee'
    'models/Question.coffee'
    'models/QuestionCollection.coffee'
    'models/RawNotification.coffee'
    'models/Reports.coffee'
    'models/Result.coffee'
    'models/ResultCollection.coffee'
    'models/Sync.coffee'
    'models/User.coffee'
    'models/UserCollection.coffee'
    'views/CaseView.coffee'
    'views/CleanView.coffee'
    'views/CsvView.coffee'
    'views/DesignView.coffee'
    'views/HelpView.coffee'
    'views/IssueView.coffee'
    'views/GeoHierarchyView.coffee'
    'views/FacilityHierarchyView.coffee'
    'views/EditDataView.coffee'
    'views/LocalConfigView.coffee'
    'views/LoginView.coffee'
    'views/ManageView.coffee'
    'views/MenuView.coffee'
    'views/MessagingView.coffee'
    'views/QuestionView.coffee'
    #'views/RainfallStationsView.coffee'
    'views/EditJsonDataAsTable.coffee'
    'views/ReportView.coffee'
    'views/ResultSummaryEditorView.coffee'
    'views/ResultsView.coffee'
    'views/SearchResultsView.coffee'
    'views/SummaryView.coffee'
    'views/SyncView.coffee'
    'views/UsersView.coffee'
    'views/WeeklyReportView.coffee'
    'views/ReportForSendingView.coffee'
    'views/ReportsForSendingView.coffee'
    'routes.coffee'
    'start.coffee'
  ])

compile_and_concat_coffee_only = (options) ->
  gutil.log "Compiling coffeescript and combining into #{app_file}"
  gulp.src app_files
    .pipe sourcemaps.init()
    .pipe coffee
      bare: true
    .on 'error', gutil.log
    .pipe concat app_file
    .pipe sourcemaps.write()
    .pipe gulp.dest compiled_js_directory
    .on 'end', options.success

compile_and_concat = (options) ->
  done = _.after 3, options.success

  gutil.log "Combining javascript libraries into #{js_library_file}"
  gulp.src js_library_files
    .pipe debug()
    .pipe sourcemaps.init()
    .pipe concat js_library_file
    .pipe sourcemaps.write()
    .pipe gulp.dest compiled_js_directory
    .on 'end', done

  gutil.log "Compiling coffeescript and combining into #{app_file}"
  gulp.src app_files
    .pipe sourcemaps.init()
    .pipe coffee
      bare: true
    .on 'error', gutil.log
    .pipe concat app_file
    .pipe sourcemaps.write()
    .pipe gulp.dest compiled_js_directory
    .on 'end', done

  gutil.log "Combining css into #{css_file}"
  gulp.src css_files
    .pipe concat css_file
    .pipe gulp.dest css_file_dir
    .on 'end', done

couchapp_push = (destination = "default") ->
  gutil.log "Pushing to couchdb"
  gulp.src("").pipe shell(["couchapp push #{destination}"])

minify = (options) ->

  done = _.after 3, options?.success

  for file in [js_library_file, app_file]
    gutil.log "uglifying: #{file}"
    gulp.src "#{compiled_js_directory}#{file}"
      .pipe uglify()
      .pipe concat file
      .pipe gulp.dest compiled_js_directory
    done()

  # Note that cssmin doesn't reduce file size much
  gutil.log "cssmin'ing #{css_file_dir}#{css_file}"
  gulp.src "#{css_file_dir}#{css_file}"
    .pipe cssmin()
    .pipe concat css_file
    .pipe gulp.dest css_file_dir
    done()

develop = () ->
  compile_and_concat_coffee_only
    success: ->
      couchapp_push()
      gutil.log "Refreshing browser"
# TODO write gulp-couchapp to push so we don't have to guess here
      #livereload.reload()
      setTimeout livereload.reload, 1000

gulp.task 'minify', ->
  compile_and_concat
    success: ->
      minify()

gulp.task 'deploy', ->
  compile_and_concat
    success: ->
      minify
        success: -
          couchapp_push("cloud")

gulp.task 'push', ->
  compile_and_concat
    success: ->
      couchapp_push()

gulp.task 'develop', ->
  livereload.listen
    start: true
  compile_and_concat
    success: ->
      couchapp_push()
      gulp.watch app_files.concat(js_library_files).concat(css_files), develop

gulp.task 'default', ->
  compile_and_concat
    success: ->
      minify
        success: ->
