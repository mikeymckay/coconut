class Config extends Backbone.Model
  initialize: ->
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

  database_name: -> @get "database_name"

  cloud_url: ->
    "http://#{@get "cloud"}/#{@get "database_name"}"

  cloud_url_with_credentials: ->
    "http://#{@get "cloud_credentials"}@#{@get "cloud"}/#{@get "database_name"}"
