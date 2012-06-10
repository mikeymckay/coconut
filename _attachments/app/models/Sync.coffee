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
        $(".sync-last-time-sent").html "pending"
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


        $(".sync-last-time-got").html "pending"

        $.couch.db(Coconut.config.database_name()).view "zanzibar/processedNotifications"
          descending: true
          include_docs: true
          limit: 1
          success: (result) ->
            mostRecentNotification = result.rows?[0]?.doc.date

            url = "#{Coconut.config.cloud_url_with_credentials()}/_design/#{Coconut.config.database_name()}/_view/notifications?&ascending=true&include_docs=true&skip=1"
            #url = "https://coconutsurveillance:zanzibar@coconutsurveillance.cloudant.com/zanzibar/_design/#{Coconut.config.database_name()}/_view/notifications?&descending=true&include_docs=true"
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
                      createdAt: moment(new Date()).format(Coconut.config.get "date_format")
                      lastModifiedAt: moment(new Date()).format(Coconut.config.get "date_format")
                    result.save()
                    notification.processed = true
                    $.couch.db(Coconut.config.database_name()).saveDoc notification
                options.success?()

                $(".sync-last-time-got").html ""
                Coconut.menuView.update()
        
        console.log Coconut.config.get "local_couchdb_admin_username"
        $.couch.login
          name: Coconut.config.get "local_couchdb_admin_username"
          password: Coconut.config.get "local_couchdb_admin_password"
          success: ->
            $.couch.replicate(
              Coconut.config.cloud_url_with_credentials(),
              Coconut.config.database_name(),
                success: ->
                  $.couch.logout()
                error: ->
                  $.couch.logout()
              ,
                doc_ids: ["_design/#{Backbone.couch_connector.config.ddoc_name}"]
            )
          error: ->
            console.log "Unable to login as local admin for replicating the design document (main application)"

