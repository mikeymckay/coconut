class Config extends Backbone.Model
  initialize: ->
    console.warn "Local and cloud database names are different: #{@database_name()} <-> #{@cloud_database_name()}" unless @database_name() is @cloud_database_name()
    @set
      _id: "coconut.config"

  fetch: (options) ->
    super()
    Coconut.config.local = new LocalConfig()
    Coconut.config.local.fetch
      success: ->
        options.success?()
      error: ->
        options.error?()
  
  url: "/configuration"

  title: -> @get("title") || "Coconut"

  # See app/config.js
  database_name: -> Backbone.couch_connector.config.db_name
  #cloud_database_name: -> Backbone.couch_connector.config.db_name + "-test"
  cloud_database_name: -> Backbone.couch_connector.config.db_name
  design_doc_name: -> Backbone.couch_connector.config.ddoc_name


  cloud_url: ->
    "http://#{@get "cloud"}/#{@cloud_database_name()}"

  cloud_url_with_credentials: ->
    "http://#{@get "cloud_credentials"}@#{@get "cloud"}/#{@cloud_database_name()}"

  cloud_log_url_with_credentials: ->
    "http://#{@get "cloud_credentials"}@#{@get "cloud"}/#{@cloud_database_name()}-log"


