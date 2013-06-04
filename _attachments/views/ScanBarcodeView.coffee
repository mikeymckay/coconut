class ScanBarcodeView extends Backbone.View

  el: '#content'

  events:
    "change .client"   : "onChange"

  render: =>
    @$el.html "
      <style>

      #feedback
      {
        color: #cc0000;
      }

      </style>
      <h1>Client ID Number</h1>
    
      <span id='feedback'></span>
      <br>
      <div>
        <label class='client' for='client_1'>Please enter the client ID</label>
        <input class='client' id='client_1' type='text'>
      </div>

      <div>
        <label class='client' for='client_2'>Please verify client ID</label>
        <input class='client' id='client_2' type='text'>
      </div>
    "
    $("input").textinput()

  onChange: ->
    client1 = $("#client_1").val()
    client2 = $("#client_2").val()

    if client1 isnt "" and client2 isnt ""
      if client1 isnt client2
        $("#feedback").html("Client IDs do not match")
      else

        Coconut.loginView.callback =
          success: ->
            Coconut.router.navigate("/summary/#{client1}",true)
        Coconut.loginView.render()
