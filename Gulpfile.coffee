gulp = require 'gulp'
coffee = require 'gulp-coffee'
concat = require 'gulp-concat'
uglify = require 'gulp-uglify'
cssmin = require 'gulp-cssmin'
shell = require 'gulp-shell'
gutil = require 'gulp-util'
debug = require 'gulp-debug'

base_dir = "/var/www/zanzibar/_attachments"

gulp.task 'coffee', ->
  gulp.src ["#{base_dir}/app/**/*.coffee","#{base_dir}/app/*.coffee"]
  .pipe coffee
    bare: true
  .pipe gulp.dest "#{base_dir}/app/"

gulp.task 'css', ->
  css = [
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
  ]
  css = ("#{base_dir}/css/#{file}" for file in css)

  gulp.src css
    .pipe cssmin()
    .pipe concat "style.min.css"
    .pipe gulp.dest "#{base_dir}/css/"

gulp.task 'libs', ->
  libs = [
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
    "tag-it.js"
    "moment.min.js"
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
  ]

  libs = ("#{base_dir}/js-libraries/#{file}" for file in libs)

  gulp.src libs
    .pipe uglify()
    .pipe concat "libs.min.js"
    .pipe gulp.dest "#{base_dir}/js/"

gulp.task 'app', ->
  app = [
    'config.js'
    'models/Alerts.js'
    'models/Case.js'
    'models/Config.js'
    'models/FacilityHierarchy.js'
    'models/GeoHierarchy.js'
    'models/Help.js'
    'models/LocalConfig.js'
    'models/Message.js'
    'models/MessageCollection.js'
    'models/Question.js'
    'models/QuestionCollection.js'
    'models/RawNotification.js'
    'models/Reports.js'
    'models/Result.js'
    'models/ResultCollection.js'
    'models/Sync.js'
    'models/User.js'
    'models/UserCollection.js'
    'views/CaseView.js'
    'views/CleanView.js'
    'views/CsvView.js'
    'views/DesignView.js'
    'views/HelpView.js'
    'views/HierarchyView.js'
    'views/LocalConfigView.js'
    'views/LoginView.js'
    'views/ManageView.js'
    'views/MenuView.js'
    'views/MessagingView.js'
    'views/QuestionView.js'
    'views/ReportView.js'
    'views/ResultSummaryEditorView.js'
    'views/ResultsView.js'
    'views/SearchResultsView.js'
    'views/SummaryView.js'
    'views/SyncView.js'
    'views/UsersView.js'
    'app.js'
  ]

  app = ("#{base_dir}/app/#{file}" for file in app)
    
  gulp.src app
#  .pipe debug()
  .pipe uglify()
  .pipe concat "app.min.js"
  .pipe gulp.dest "#{base_dir}/js/"

gulp.task 'default', [
  'coffee'
  'libs'
  'css'
  'app'
]

gulp.watch "#{base_dir}/*.html", ['app']
gulp.watch ["#{base_dir}/app/**/*.coffee","#{base_dir}/app/*.coffee"], ['coffee','app']

