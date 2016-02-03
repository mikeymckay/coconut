class ReportForSendingView extends Backbone.View

  @textFields = [
    "URL"
    "Description"
    "Code To Execute"
    "Email Recipients"
    "SMS Recipients"
  ]

  @readOnlyFields = [
    "Last Sent"
  ]

  @numericFields = ["Minutes between sending","Seconds to wait for URL to load"]

  @requiredFields = [
    "URL"
    "Minutes between sending"
  ]

  el: '#content'

  events:
    "click button#save": "save"
  
  render: =>
    console.log @reportForSending

    @$el.html "

      <style>
        label { display: inline-block; width: 140px; text-align: right; }
        textarea { width: 50%;}
      </style>

      <div id='message'>
      </div>

      #{
      _(ReportForSendingView.textFields).map (textField) =>
        "
          <div>
            <label>#{textField}</label>
            <textarea name=#{s.camelize(textField)}>#{
                if @reportForSending?[textField]? then @reportForSending[textField] else ""
              }</textarea>
          </div>
        "
      .join ""
      }

      #{
      _(ReportForSendingView.numericFields).map (numericField) =>
        "
        <div>
          <label>#{numericField}</label>
          <input type='number' name=#{s.camelize(numericField)} value='#{if @reportForSending?[numericField]? then @reportForSending[numericField] else ""}'></input>
        </div>
        "
      .join ""
      }
      <label>Screenshot</label>
      <input type='checkbox' name='Screenshot' #{if @reportForSending?.Screenshot is true then 'checked' else ''}></input>
      #{
      _(ReportForSendingView.readOnlyFields).map (field) =>
        "
          <div>
            <label>#{field}</label>
            <span>#{if @reportForSending?[field]? then @reportForSending[field] else ""}</span>
          </div>
        "
      .join ""
      }
      <button type='button' id='save'>Save</button>
    "
    
  save: =>
    @reportForSending = {} unless @reportForSending?


    _(ReportForSendingView.textFields.concat ReportForSendingView.numericFields).map (field) =>
      @reportForSending[field] = $("[name=#{s.camelize(field)}]").val()

    @reportForSending.Screenshot = $("[name=Screenshot]").is(":checked")

    validationErrors = []
    _(ReportForSendingView.requiredFields).each (requiredField) =>
      if @reportForSending[requiredField] is ""
        validationErrors.push "<li> #{requiredField} is required"

    if validationErrors.length > 0
      $('#message').html validationErrors.join("<br/>")
      .show()
      .fadeOut(10000)

    
    unless @reportForSending._id?
      @reportForSending._id = "reportForSending__" + _(@reportForSending).values().join("_").replace(/\//g,"").replace("https:","").replace("http:","")

    Coconut.database.saveDoc @reportForSending,
      error: (error) ->
        $("#message").html("Error saving: #{JSON.stringify error}")
        .show()
        .fadeOut(10000)
      success: =>
        Coconut.router.navigate "#edit/reportForSending/#{@reportForSending._id}"
        @render()
        $("#message").html("Report for sending saved")
        .show()
        .fadeOut(2000)
