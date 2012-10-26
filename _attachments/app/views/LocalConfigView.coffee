class LocalConfigView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
      <form id='local-config'>
        <fieldset>
          <legend>Mode</legend>
            <label for='cloud'>Cloud (reporting system)</label>
            <input id='cloud' name='mode' type='radio' value='cloud'></input>
            <label for='mobile'>Mobile (data collection, probably on a tablet)</label>
            <input id='mobile' name='mode' type='radio' value='mobile'></input>
        </fieldset>
        <button>Save</button>
        <div id='message'></div>
      </form>
    "
    @$el.find('input[type=radio],input[type=checkbox]').checkboxradio()
    @$el.find('button').button()
    Coconut.config.local.fetch
      success: ->
        js2form($('#local-config').get(0), Coconut.config.local.toJSON())
      error: ->
        $('#message').html "Complete the fields before continuing"

  events:
    "click #local-config button": "save"

  save: ->
    result = $('#local-config').toObject()
    if result.mode
      Coconut.config.local.save result,
        success: ->
          Coconut.router.navigate("",false)
          location.reload()
    else
      $('#message').html "Fields incomplete"
    return false
