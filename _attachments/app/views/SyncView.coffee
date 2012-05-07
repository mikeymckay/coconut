class SyncView extends Backbone.View
  initialize: ->
    @sync = new Sync()

  el: '#content'

  render: =>
    @sync.fetch
      success: =>
        @$el.html "
          <h2>Cloud Server: #{@sync.target()}</h2>
          <a href='#sync/send'>Send data (last done: #{@sync.last_time("send")})</a>
          <a href='#sync/get'>Get data (last done: #{@sync.last_time("get")})</a>
          "
        $("a").button()
      # synclog doesn't exist yet, create it and re-render
      error: =>
        @sync.save()
        _.delay(@render,1000)

