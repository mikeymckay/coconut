class LocalConfig extends Backbone.Model
  initialize: ->
    @set
      _id: "coconut.config.local"

  url: "/local_configuration"

  httpPostTarget: ->
    @get "http-post-target" ? Coconut.config.get "http-post-target"
