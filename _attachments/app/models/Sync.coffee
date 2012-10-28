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
    result = @get("last_get_time")
    if result
      return moment(@get("last_get_time")).fromNow()
    else
      return "never"

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
    Coconut.debug message
    $(".sync-get-status").html message
#    @save
#      last_get_log: @get("last_get_log") + message

  getFromCloud: (options) =>
    @fetch
      success: =>
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
                        @log "Finished, now refreshing app..."
                        @save
                          last_get_time: new Date().getTime()
                        options?.success?()
                        _.delay ->
                          document.location.reload()
                        , 2000
                      error: (error) =>
                        $.couch.logout()
                        @log "Error updating application: #{error.toJSON()}"
                  error: (error) =>
                    $.couch.logout()
                    @log "Error updating design document: #{error.toJSON()}"
              error: (error) =>
                @log "Error logging in as local admin: #{error.toJSON()}"

  getNewNotifications: (options) ->
    @log "Looking for most recent Case Notification."
    $.couch.db(Coconut.config.database_name()).view "zanzibar/rawNotificationsConvertedToCaseNotifications"
      descending: true
      include_docs: true
      limit: 1
      success: (result) ->
        mostRecentNotification = result.rows?[0]?.doc.date

        url = "#{Coconut.config.cloud_url_with_credentials()}/_design/#{Coconut.config.database_name()}/_view/notifications?&ascending=true&include_docs=true"
        url += "&startkey=\"#{mostRecentNotification}\"&skip=1" if mostRecentNotification

        district = User.currentUser.get("district")
        healthFacilities = WardHierarchy.allWards district: district
        healthFacilities = [] unless district
        @log "Looking for USSD notifications after#{mostRecentNotification}."
        $.ajax
          url: url
          dataType: "jsonp"
          success: (result) ->
            @log "Found #{result.rows.length} new Case Notification#{if result.rows.length > 1 then "s" else ""}, filtering for these health facilities (district: #{district}): #{healthFacilities.join(",")}"
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
                @log "Created new case notification with ID #{result.MalariaCaseID} from #{result.FacilityName}"
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
