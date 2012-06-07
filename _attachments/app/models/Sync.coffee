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

  # Do a filtered replication but setup a changes listener
  # that will process the incoming results
  getFromCloud: (options) ->
    @fetch
      success: =>
        @changes?.stop()
        @changes = $.couch.db(Coconut.config.database_name()).changes(null,
          filter: Coconut.config.database_name() + "/casesByFacility"
          healthFacilities: (WardHierarchy.allWards
            district: Coconut.config.local.get("district")
          ).join(',')
        )
        @changes.onChange (changes) ->
          _.each changes.results, (result) ->
            $.couch.db(Coconut.config.database_name()).openDoc result.id,
              success: (doc) ->
                result = new Result
                  question: "Case Notification"
                  MalariaCaseID: doc.caseid
                  FacilityName: doc.hf
                  createdAt: moment(new Date()).format(Coconut.config.get "date_format")
                  lastModifiedAt: moment(new Date()).format(Coconut.config.get "date_format")
                result.save()
                Coconut.menuView.update()
        $(".sync-last-time-got").html "pending"
        $.couch.replicate(
          Coconut.config.cloud_url_with_credentials(),
          Coconut.config.database_name(),
            success: (response) =>
              @save
                last_get_result: response
              options.success?()
            error: ->
              options.error?()
          ,
            filter: Coconut.config.database_name() + "/casesByFacility"
            query_params:
              healthFacilities: (WardHierarchy.allWards
                district: Coconut.config.local.get("district")
              ).join(',')
        )
        $.couch.replicate(
          Coconut.config.cloud_url_with_credentials(),
          Coconut.config.database_name(),
            success: (response) =>
              @save
                last_get_result: response
              options.success?()
            error: ->
              options.error?()
          ,
            doc_ids: ["_design/#{Backbone.couch_connector.config.ddoc_name}"]
        )
