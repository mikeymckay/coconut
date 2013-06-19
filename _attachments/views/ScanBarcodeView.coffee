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

      .client
      {
        text-transform: uppercase;
      }

      </style>
      <h1>Find/Create Client</h1>
    
      <span id='feedback'></span>
      <br>
      <div>
        <label for='client_1'>Client ID</label>
        <input class='client' id='client_1' type='text'>
      </div>

      <div>
        <label for='client_2'>Confirm client ID</label>
        <input class='client' id='client_2' type='text'>
      </div>
    "
    $("input").textinput()
    $("head title").html "Coconut Find/Create Client"


  onChange: ->

    # || '' catches the case when the form has already been
    # submitted due to the enter key being pressed 

    client1 = ($("#client_1").val() || '').toUpperCase()
    client2 = ($("#client_2").val() || '').toUpperCase()

    unless client1.match(/-/g)?.length is 2
      client1 = client1.replace(/^(.)(.)(.)/,"$1-$2-$3")
      $("#client_1").val(client1)

    unless client2.match(/-/g)?.length is 2
      client2 = client2.replace(/^(.)(.)(.)/,"$1-$2-$3")
      $("#client_2").val(client2)

    if client1 isnt "" and client2 isnt ""
      if client1 isnt client2
        $("#feedback").html("Client IDs do not match")
      else

        Coconut.loginView.callback =
          success: ->
            $("head title").html "Coconut"
            Coconut.router.navigate("/summary/#{client1}",true)
        Coconut.loginView.render()
