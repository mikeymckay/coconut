class SyncView extends Backbone.View
  initialize: ->
    @sync = new Sync()

  el: '#content'

  render: =>
      @$el.html "
        <h2>Cloud Server: <span class='sync-target'>#{@sync.target()}</span></h2>
        <a href='#sync/send'>Send data (last done: <span class='sync-last-time-sent'></span>)</a>
        <a href='#sync/get'>Get data (last done: <span class='sync-last-time-got'></span>)</a>
        "
      $("a").button()
      @update()

  update: =>
    @sync.fetch
      success: =>
        $(".sync-last-time-sent").html @sync.last_time("send")
        $(".sync-last-time-got").html @sync.last_time("get")
      # synclog doesn't exist yet, create it and re-render
      error: =>
        @sync.save()
        _.delay(@update,1000)
    
