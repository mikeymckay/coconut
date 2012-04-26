class Config extends Backbone.Model
  initialize: ->
    @id = "coconut.config"
  
  url: "/configuration"

  title: -> @get("title") || "Coconut"

  database_name: -> @get "database_name"

  cloud_url: ->
    "https://#{@get "cloud"}/#{@get "database_name"}"

  cloud_url_with_credentials: ->
    "https://#{@get "cloud_credentials"}@#{@get "cloud"}/#{@get "database_name"}"
