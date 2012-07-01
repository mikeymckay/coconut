class Sync extends Backbone.Model
  initialize: ->
    @set
      _id: "SyncLog"

  url: "/sync"

  target: -> Coconut.config.cloud_url()

  last_send: =>
    return @get("last_send_result")?.history[0]

  last_send_time: =>
    result = @last_send?.start_time
    if result
      return moment(result).fromNow()
    else
      return "never"

  last_get: =>
    return @get("last_get_log")

  last_get_time: =>
    return moment(@get("last_get_time")).fromNow()

  sendToCloud: (options) ->
    @fetch
      success: =>
        $(".sync-sent-status").html "pending"
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

  log: (message) =>
    console.log message
    $(".sync-get-status").html message
    @save
      last_get_log: @get("last_get_log") + message

  getFromCloud: (options) =>
    @fetch
      success: =>
        @clear()
        @log "Getting new case notifications..."
        @getNewNotifications
          success: =>
            $.couch.login
              name: Coconut.config.get "local_couchdb_admin_username"
              password: Coconut.config.get "local_couchdb_admin_password"
              success: =>
                @log "Updating design document..."
                @replicateDesignDoc
                  success: =>
                    @log "Updating application documents..."
                    @replicateApplicationDocs
                      success: =>
                        $.couch.logout()
                        @log "Finished"
                        @save
                          last_get_time: new Date().getTime()
                        $(".sync-get-status").html "A few seconds ago"
                        options.success()
                      error: (error) =>
                        $.couch.logout()
                        @log "Error updating application: #{error.toJSON()}"
                  error: (error) =>
                    $.couch.logout()
                    @log "Error updating design document: #{error.toJSON()}"
              error: (error) =>
                @log "Error logging in as local admin: #{error.toJSON()}"

  getNewNotifications: (options) ->
    $.couch.db(Coconut.config.database_name()).view "zanzibar/rawNotificationsConvertedToCaseNotifications"
      descending: true
      include_docs: true
      limit: 1
      success: (result) ->
        mostRecentNotification = result.rows?[0]?.doc.date

        url = "#{Coconut.config.cloud_url_with_credentials()}/_design/#{Coconut.config.database_name()}/_view/notifications?&ascending=true&include_docs=true&skip=1"
        url += "&startkey=\"#{mostRecentNotification}\"" if mostRecentNotification

        healthFacilities = WardHierarchy.allWards district: Coconut.config.local.get("district")
        $.ajax
          url: url
          dataType: "jsonp"
          success: (result) ->
            _.each result.rows, (row) ->
              notification = row.doc

              if _.include(healthFacilities, notification.hf)

                result = new Result
                  question: "Case Notification"
                  MalariaCaseID: notification.caseid
                  FacilityName: notification.hf
                  Shehia: notification.shehia
                  Name: notification.name
                result.save()

                notification.hasCaseNotification = true
                $.couch.db(Coconut.config.database_name()).saveDoc notification
            options.success?()

  replicate: (options) ->
    $.couch.login
      name: Coconut.config.get "local_couchdb_admin_username"
      password: Coconut.config.get "local_couchdb_admin_password"
      success: ->
        $.couch.replicate(
          Coconut.config.cloud_url_with_credentials(),
          Coconut.config.database_name(),
            success: ->
              options.success()
            error: ->
              options.error()
          ,
            options.replicationArguments
        )
      error: ->
        console.log "Unable to login as local admin for replicating the design document (main application)"

  replicateDesignDoc: (options) =>
    @replicate _.extend options,
      replicationArguments:
        doc_ids: ["_design/#{Backbone.couch_connector.config.ddoc_name}"]

  replicateApplicationDocs: (options) =>
    @replicate _.extend options,
      replicationArguments:
        filter: "#{Backbone.couch_connector.config.ddoc_name}/docsForApplication"
