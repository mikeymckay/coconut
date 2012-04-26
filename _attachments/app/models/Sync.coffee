class Sync extends Backbone.Model
  initialize: ->
    @set
      _id: "SyncLog"

  url: "/sync"

  target: -> Coconut.config.cloud_url()

  last: (type) ->
    return @get("last_#{type}_result")?.history[0]

  last_time: (type) ->
    result = @last(type)?.start_time
    if result
      return moment(result).fromNow()
    else
      return "never"

  sendToCloud: (options) ->
    @fetch
      success: =>
        $.couch.replicate(
          Coconut.config.database_name(),
          Coconut.config.cloud_url_with_credentials(),
            success: (response) =>
              @save
                last_send_result: response
              options.success()
            error: ->
              options.error()
        )

  getFromCloud: (options) ->
    @fetch
      success: =>
        $.couch.replicate(
          Coconut.config.cloud_url_with_credentials(),
          Coconut.config.database_name(),
            success: (response) =>
              @save
                last_get_result: response
              options.success()
            error: ->
              options.error()
        )
