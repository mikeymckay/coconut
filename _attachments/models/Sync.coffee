class Sync extends Backbone.Model
  initialize: ->
    @set
      _id: "SyncLog"

  url: "/sync"

  last_send: =>
    return @get("last_send_result")?.history[0]

  last_send_time: =>
    result = @get("last_send_time") || @last_send?.start_time
    
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

  sendToCloud: (options) =>
    @fetch
      success: =>
        @log "Sending data to #{Coconut.config.database_name()}"
        $.couch.replicate(
          Coconut.config.database_name(),
          Coconut.config.cloud_url_with_credentials(),
            success: (response) =>
              @save
                last_send_result: response
              options.success(response)
            error: (error) ->
              options.error(error)
        )

  log: (message) =>
    Coconut.debug message
    $(".sync-get-status").html message
    $("#message").append message + "<br/>"
#    @save
#      last_get_log: @get("last_get_log") + message

  getFromCloud: (options) =>
    @fetch
      success: =>
        $.couch.login
          name: Coconut.config.get "local_couchdb_admin_username"
          password: Coconut.config.get "local_couchdb_admin_password"
          complete: =>
            @log "Updating application documents (forms, users, application code)"
            @replicateApplicationDocs
              success: =>
                #$.couch.logout()
                @log "Finished"
                @save
                  last_get_time: new Date().getTime()
                options?.success?()
                reload_delay_seconds = 2
                @log("Reloading application in #{reload_delay_seconds} seconds")
                _.delay document.location.reload, reload_delay_seconds*1000
              error: (error) =>
                $.couch.logout()
                @log "Error updating application: #{error}"
          error: (error) =>
            @log "Error logging in as local admin: #{error}, trying to proceed anyway in case we are in admin party"


  sendAndGetFromCloud: (options) =>

    @log "Checking for internet. (Is #{Coconut.config.cloud_url()} is reachable?) Please wait."
    $.ajax
      # This requires a CORS enabled server to work
      url: Coconut.config.cloud_url()
      error: (error) =>
        @log "ERROR! #{Coconut.config.cloud_url()} is not reachable. Either the internet is not working or the site is down: #{error}"
        options?.error()
        @save
          last_send_error: true
      success: =>
        @log "#{Coconut.config.cloud_url()} is reachable, so internet is available."
        statusChecker = setInterval(@checkStatus(),5000)
        @sendToCloud
          success: (result) =>
            @log "Data sent: <small><pre>#{JSON.stringify result,undefined,2}</pre></small>"
            @replicate
              success: (result) =>
                @log "Data received: <small><pre>#{JSON.stringify result,undefined,2}</pre></small>"
                @log "Sync Complete"
                @save
                  last_get_time: new Date().getTime()
                options?.success?()
              error: =>
                @log "Sync fail during get"
                options?.error?()
          error: (error) =>
            @log "Synchronization fail during send: #{JSON.stringify error}"

  checkStatus: =>
    $.ajax
      url: "#{Coconut.config.cloud_url()}/_active_tasks"
      success: (result) =>
        @log result

  getNewNotifications: (options) ->
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/rawNotificationsConvertedToCaseNotifications"
      descending: true
      include_docs: true
      limit: 1
      success: (result) ->
        mostRecentNotification = result.rows?[0]?.doc.date

        url = "#{Coconut.config.cloud_url_with_credentials()}/_design/#{Coconut.config.database_name()}/_view/notifications?&ascending=true&include_docs=true&skip=1"
        url += "&startkey=\"#{mostRecentNotification}\"" if mostRecentNotification

        healthFacilities = WardHierarchy.allWards district: User.currentUser.get("district")
        healthFacilities = [] unless User.currentUser.get("district")?
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

  replicate: (options) =>
    @log "Preparing to receive data"
    $.couch.login
      name: Coconut.config.get "local_couchdb_admin_username"
      password: Coconut.config.get "local_couchdb_admin_password"
      complete: =>
        @log "Receiving data from #{Coconut.config.database_name()}"
        $.couch.replicate(
          Coconut.config.cloud_url_with_credentials(),
          Coconut.config.database_name(),
            success: (result) =>
              @log "Data received: <small><pre>#{JSON.stringify result,undefined,2}</pre></small>"
              @log "Returning coconut.config.local to original state"
              originalLocalConfig = Coconut.config.local.toJSON()
              delete originalLocalConfig._rev
              Coconut.config.local.fetch
                success: =>
                  Coconut.config.local.save originalLocalConfig,
                    success: =>
                      @save
                        last_get_time: new Date().getTime()
                      options.success()
                    error: (error) =>
                      @log "Couldn't fix coconut.config.local: #{error}"
                    
            error: (error) =>
              @log "Error receiving data from #{Coconut.config.database_name()}: #{JSON.stringify error}"
              options.error()
          ,
            options.replicationArguments
        )
      error: =>
        @log "Unable to login as local admin for replicating the design document (main application),  trying to proceed anyway in case we are in admin party."

  replicateApplicationDocs: (options) =>
    # Updating design_doc, users & forms
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/byCollection",
      keys: ["question","user"]
      include_docs: false
      success: (result) =>
        doc_ids = _.pluck result.rows, "id"
        doc_ids.push "_design/#{Coconut.config.design_doc_name()}"
        doc_ids.push "coconut.config"
        @log "Updating #{doc_ids.length} docs (users, forms, configuration and the design document). Please wait."
        @replicate _.extend options,
          replicationArguments:
            doc_ids: doc_ids


  migrate: ->

    createAndMigrate = (doc_ids) ->
      console.log "encoding doc_ids"
      doc_ids = _(doc_ids).map (doc_id) -> encodeURIComponent doc_id
      console.log "finished encoding"
      $.couch.db("migrate").create
        success: ->
          $.couch.replicate "coconut","migrate",
            success: (result) ->
              console.log JSON.stringify result
              $.couch.db("coconut").drop
                success: ->
                  $.couch.db("coconut").create
                    success: ->
                      $.couch.replicate "migrate","coconut",
                        success: (result) ->
                          console.log JSON.stringify result
                          $.couch.db("migrate").drop
                            success: ->
                              console.log "DONE"
          ,
            doc_ids: doc_ids

    doc_ids = []
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/byCollection",
      keys: ["question","user"]
      include_docs: false
      success: (result) =>
        doc_ids.push.apply(doc_ids, _.pluck result.rows, "id")
        doc_ids.push "_design/#{Coconut.config.design_doc_name()}"
        doc_ids.push "coconut.config"
        doc_ids.push "coconut.config.local"
        console.log doc_ids.length
        $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/clients",
          include_docs: false
          success: (result) =>
            doc_ids.push.apply(doc_ids, _.pluck result.rows, "id")
            console.log doc_ids.length

            $.couch.allDbs
              success: (result) ->
                if _(result).contains "migrate"
                  $.couch.db("migrate").drop
                    success: ->
                      createAndMigrate(doc_ids)
                else
                  createAndMigrate(doc_ids)



