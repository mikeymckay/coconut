window.SkipTheseWhen = ( argQuestions, result ) ->
  questions = []
  argQuestions = argQuestions.split(/\s*,\s*/)
  for question in argQuestions
    questions.push window.questionCache[question]
  disabledClass = "disabled_skipped"

  for question in questions
    if result
      question.addClass disabledClass
    else
      question.removeClass disabledClass


window.ResultOfQuestion = ( name ) -> return window.getValueCache[name]?() || null

class QuestionView extends Backbone.View

  initialize: (options) =>
    (@[key] = value for key, value of options)
    Coconut.resultCollection ?= new ResultCollection()
    @autoscrollTimer = 0

  el: '#content'

  triggerChangeIn: ( names ) ->

    for name in names
      elements = []
      elements.push window.questionCache[name].find("input, select, textarea")
      $(elements).each (index, element) =>
        event = target : element
        @actionOnChange event

  render: =>

    @$el.html "
    <style>
      .message
      {
        color: grey;
        font-weight: bold;
        padding: 10px;
        border: 1px yellow dotted;
        background: yellow;
        display: none;
      }
    </style>
      <div style='position:fixed; right:5px; color:white; background-color: #333; padding:20px; display:none; z-index:10' id='messageText'>
        Saving...
      </div>
      <h1>#{@model.id}</h1>
      <div id='question-view'>
        <form>
          #{@toHTMLForm(@model)}
        </form>
      </div>
    "

    @updateCache()

    # for first run
    @updateSkipLogic()
    
    # skipperList is a list of questions that use skip logic in their action on change events
    skipperList = []

    $(@model.get("questions")).each (index, question) =>

      # remember which questions have skip logic in their actionOnChange code 
      skipperList.push(question.safeLabel()) if question.actionOnChange().match(/skip/i)
      
      if question.get("action_on_questions_loaded") isnt ""
        CoffeeScript.eval question.get "action_on_questions_loaded"

    js2form($('form').get(0), @result.toJSON())

    # Trigger a change event for each of the questions that contain skip logic in their actionOnChange code
    @triggerChangeIn skipperList

    @$el.find("input[type=text],input[type=number],input[type='autocomplete from previous entries'],input[type='autocomplete from list']").textinput()
    @$el.find('input[type=radio],input[type=checkbox]').checkboxradio()
    @$el.find('ul').listview()
    @$el.find('select').selectmenu()
    @$el.find('a').button()
    @$el.find('input[type=date]').datebox
      mode: "calbox"
      dateFormat: "%d-%m-%Y"

#    tagSelector = "input[name=Tags],input[name=tags]"
#    $(tagSelector).tagit
#      availableTags: [
#        "complete"
#      ]
#      onTagChanged: ->
#        $(tagSelector).trigger('change')

    _.each $("input[type='autocomplete from list'],input[type='autocomplete from previous entries']"), (element) ->
      element = $(element)
      if element.attr("type") is 'autocomplete from list'
        source = element.attr("data-autocomplete-options").replace(/\n|\t/,"").split(/, */)
        minLength = 0
      else
        source = document.location.pathname.substring(0,document.location.pathname.indexOf("index.html")) + "_list/values/byValue?key=\"#{element.attr("name")}\""
        minLength = 1

      element.autocomplete
        source: source
        minLength: minLength
        target: "##{element.attr("id")}-suggestions"
        callback: (event) ->
          element.val($(event.currentTarget).text())
          element.autocomplete('clear')

    $('input, textarea').attr("readonly", "true") if @readonly

  events:
    "change #question-view input"    : "onChange"
    "change #question-view select"   : "onChange"
    "change #question-view textarea" : "onChange"
    "click #question-view button:contains(+)" : "repeat"
    "click #question-view a:contains(Get current location)" : "getLocation"
    "click .next_error"   : "runValidate"
    "click .validate_one" : "onValidateOne"

  runValidate: -> @validateAll()

  onChange: (event) ->
    $target = $(event.target)

    #
    # Don't duplicate events unless 1 second later
    #
    eventStamp = $target.attr("id")

    return if eventStamp == @oldStamp and (new Date()).getTime() < @throttleTime + 1000

    @throttleTime = (new Date()).getTime()
    @oldStamp     = eventStamp

    targetName = $target.attr("name")

    if targetName == "complete"
      if @changedComplete
        @changedComplete = false
        return

      @validateAll()
      # Update the menu
      Coconut.menuView.update()
    else
      @changedComplete = false
      messageVisible = window.questionCache[targetName].find(".message").is(":visible")
      unless messageVisible
        wasValid = @validateOne
          key: targetName
          autoscroll: false
          button: "<button type='button' data-name='#{targetName}' class='validate_one'>Validate</button>"

    @save()

    @updateSkipLogic()
    @actionOnChange(event)

    @autoscroll(event) if wasValid and not messageVisible

  onValidateOne: (event) -> 
    $target = $(event.target)
    name = $(event.target).attr('data-name')
    @validateOne
      key : name
      autoscroll: true
      leaveMessage : false
      button : "<button type='button' data-name='#{name}' class='validate_one'>Validate</button>"

  validateAll: () ->

    isValid = true

    for key in window.keyCache

      questionIsntValid = not @validateOne
        key          : key
        autoscroll   : isValid
        leaveMessage : false

      if isValid and questionIsntValid
        isValid = false

    @completeButton isValid

    $("[name=complete]").scrollTo() if isValid

    return isValid


  validateOne: ( options ) ->

    key          = options.key          || ''
    autoscroll   = options.autoscroll   || false
    button       = options.button       || "<button type='button' class='next_error'>Next Error</button>"
    leaveMessage = options.leaveMessage || false

    $question = window.questionCache[key]
    $message  = $question.find(".message")

    try
      message = @isValid(key)
    catch e
      alert "isValid error in #{key}\n#{e}"
      message = ""

    if $message.is(":visible") and leaveMessage
      if message is "" then return true else return false

    if message is ""
      $message.hide()
      if autoscroll
        @autoscroll $question
      return true
    else
      $message.show().html("
        #{message}
        #{button}
      ").find("button").button()
      return false


  isValid: ( question_id ) ->

    return unless question_id
    result = []

    questionWrapper = window.questionCache[question_id]
    
    # early exit, don't validate labels
    return "" if questionWrapper.hasClass("label")

    question        = $("[name=#{question_id}]", questionWrapper)

    type            = $(questionWrapper.find("input").get(0)).attr("type")
    labelText       = 
      if type is "radio"
        $("label[for=#{question.attr("id").split("-")[0]}]", questionWrapper).text() || ""
      else
        $("label[for=#{question.attr("id")}]", questionWrapper)?.text()
    required        = questionWrapper.attr("data-required") is "true"
    validation      = unescape(questionWrapper.attr("data-validation"))
    validation      = null if validation is "undefined"

    value           = window.getValueCache[question_id]()

    #
    # Exit early conditions
    #

    # don't evaluate anything that's been skipped. Skipped = valid
    return "" if not questionWrapper.is(":visible")
    
    # "" = true
    return "" if question.find("input").length != 0 and (type == "checkbox" or type == "radio")

    result.push "'#{labelText}' is required." if required && value is "" or value is null

    if validation? && validation isnt ""

      try
        validationFunctionResult = (CoffeeScript.eval("(value) -> #{validation}", {bare:true}))(value)
        result.push validationFunctionResult if validationFunctionResult?
      catch error
        return '' if error == 'invisible reference'
        alert "Validation error for #{question_id} with value #{value}: #{error}"

    if result.length isnt 0
      return result.join("<br>") + "<br>"

    return ""

  autoscroll: (event) ->

    clearTimeout @autoscrollTimer

    if event.jquery
      $div = event
      name = $div.attr("data-question-name")
    else
      $target = $(event.target)
      name = $target.attr("name")
      $div = window.questionCache[name]


    @$next = $div.next()

    if not @$next.is(":visible")
      @$next = @$next.next() while not @$next.is(":visible")

    if @$next.is(":visible")
      $(window).on( "scroll", => $(window).off("scroll"); clearTimeout @autoscrollTimer; )
      @autoscrollTimer = setTimeout(
        => 
          $(window).off( "scroll" )
          @$next.scrollTo().find("input[type=text],input[type=number]").focus()
        1000
      )

  # takes an event as an argument, and looks for an input, select or textarea inside the target of that event.
  # Runs the change code associated with that question.
  actionOnChange: (event) ->

    nodeName = $(event.target).get(0).nodeName
    $target = 
      if nodeName is "INPUT" or nodeName is "SELECT" or nodeName is "TEXTAREA"
        $(event.target)
      else
        $(event.target).parent().parent().parent().find("input,textarea,select")

    name = $target.attr("name")
    $divQuestion = $(".question [data-question-name=#{name}]")
    code = $divQuestion.attr("data-action_on_change")
    try 
      value = ResultOfQuestion(name)
    catch error
      return if error == "invisible reference"

    return if code == "" or not code?
    code = "(value) -> #{code}"
    try
      newFunction = CoffeeScript.eval.apply(@, [code])
      newFunction(value)
    catch error
      name = ((/function (.{1,})\(/).exec(error.constructor.toString())[1])
      message = error.message
      alert "Action on change error in question #{$divQuestion.attr('data-question-id') || $divQuestion.attr("id")}\n\n#{name}\n\n#{message}"


  updateSkipLogic: ->
    
    for name, $question of window.questionCache

      skipLogicCode = window.skipLogicCache[name]
      continue if skipLogicCode is "" or not skipLogicCode?

      try
        result = eval(skipLogicCode)
      catch error
        if error == "invisible reference"
          result = true
        else
          name = ((/function (.{1,})\(/).exec(error.constructor.toString())[1])
          message = error.message
          alert "Skip logic error in question #{$question.attr('data-question-id')}\n\n#{name}\n\n#{message}"

      if result
        $question[0].style.display = "none"
      else
        $question[0].style.display = ""



  # We throttle to limit how fast save can be repeatedly called
  save: _.throttle( ->
      
      currentData = $('form').toObject(skipEmpty: false)

      # Make sure lastModifiedAt is always updated on save
      currentData.lastModifiedAt = moment(new Date()).format(Coconut.config.get "datetime_format")
      currentData.savedBy = $.cookie('current_user')
      @result.save currentData,
        success: (model) ->
          $("#messageText").slideDown().fadeOut()

    , 1000)

  completeButton: ( value ) ->
    @changedComplete = true
    if $('[name=complete]').prop("checked") isnt value
      $('[name=complete]').click()

  toHTMLForm: (questions = @model, groupId) ->
    window.skipLogicCache = {}
    # Need this because we have recursion later
    questions = [questions] unless questions.length?
    _.map(questions, (question) =>

      if question.repeatable() == "true" then repeatable = "<button>+</button>" else repeatable = ""
      if question.type()? and question.label()? and question.label() != ""
        name = question.safeLabel()
        window.skipLogicCache[name] = if question.skipLogic() isnt '' then CoffeeScript.compile(question.skipLogic(),bare:true) else ''
        question_id = question.get("id")
        if question.repeatable() == "true"
          name = name + "[0]"
          question_id = question.get("id") + "-0"
        if groupId?
          name = "group.#{groupId}.#{name}"
        return "
          <div 
            #{
            if question.validation()
              "data-validation = '#{escape(question.validation())}'" if question.validation() 
            else
              ""
            } 
            data-required='#{question.required()}'
            class='question #{question.type?() or ''}'
            data-question-name='#{name}'
            data-question-id='#{question_id}'
            data-action_on_change='#{_.escape(question.actionOnChange())}'

          >
          #{
          "<label type='#{question.type()}' for='#{question_id}'>#{question.label()} <span></span></label>" unless ~question.type().indexOf('hidden')
          }
          <div class='message'></div>
          #{
            switch question.type()
              when "textarea"
                "<input name='#{name}' type='text' id='#{question_id}' value='#{_.escape(question.value())}'></input>"
# Selects look lame - use radio buttons instead or autocomplete if long list
#              when "select"
#                "
#                  <select name='#{name}'>#{
#                    _.map(question.get("select-options").split(/, */), (option) ->
#                      "<option>#{option}</option>"
#                    ).join("")
#                  }
#                  </select>
#                "
              when "select"
                if @readonly
                  question.value()
                else

                  html = "<select>"
                  for option, index in question.get("select-options").split(/, */)
                    html += "<option name='#{name}' id='#{question_id}-#{index}' value='#{option}'>#{option}</option>"
                  html += "</select>"
              when "radio"
                if @readonly
                  "<input name='#{name}' type='text' id='#{question_id}' value='#{question.value()}'></input>"
                else
                  options = question.get("radio-options")
                  _.map(options.split(/, */), (option,index) ->
                    "
                      <label for='#{question_id}-#{index}'>#{option}</label>
                      <input type='radio' name='#{name}' id='#{question_id}-#{index}' value='#{_.escape(option)}'/>
                    "
                  ).join("")
              when "checkbox"
                if @readonly
                  "<input name='#{name}' type='text' id='#{question_id}' value='#{_.escape(question.value())}'></input>"
                else
                  "<input style='display:none' name='#{name}' id='#{question_id}' type='checkbox' value='true'></input>"
              when "autocomplete from list", "autocomplete from previous entries"
                "
                  <!-- autocomplete='off' disables browser completion -->
                  <input autocomplete='off' name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}' data-autocomplete-options='#{question.get("autocomplete-options")}'></input>
                  <ul id='#{question_id}-suggestions' data-role='listview' data-inset='true'/>
                "
#              when "autocomplete from previous entries" or ""
#                "
#                  <!-- autocomplete='off' disables browser completion -->
#                  <input autocomplete='off' name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}'></input>
#                  <ul id='#{question_id}-suggestions' data-role='listview' data-inset='true'/>
#                "
              when "location"
                "
                  <a data-question-id='#{question_id}'>Get current location</a>
                  <label for='#{question_id}-description'>Location Description</label>
                  <input type='text' name='#{name}-description' id='#{question_id}-description'></input>
                  #{
                    _.map(["latitude", "longitude"], (field) ->
                      "<label for='#{question_id}-#{field}'>#{field}</label><input readonly='readonly' type='number' name='#{name}-#{field}' id='#{question_id}-#{field}'></input>"
                    ).join("")
                  }
                  #{
                    _.map(["altitude", "accuracy", "altitudeAccuracy", "heading", "timestamp"], (field) ->
                      "<input type='hidden' name='#{name}-#{field}' id='#{question_id}-#{field}'></input>"
                    ).join("")
                  }
                "

              when "image"
                "<img style='#{question.get "image-style"}' src='#{question.get "image-path"}'/>"
              when "label"
                ""
              else
                "<input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}'></input>"
          }
          </div>
          #{repeatable}
        "
      else
        newGroupId = question_id
        newGroupId = newGroupId + "[0]" if question.repeatable()
        return "<div data-group-id='#{question_id}' class='question group'>" + @toHTMLForm(question.questions(), newGroupId) + "</div>" + repeatable
    ).join("")

  updateCache: ->
    window.questionCache = {}
    window.getValueCache = {}
    window.$questions = $(".question")

    for question in window.$questions
      name = question.getAttribute("data-question-name")
      if name? and name isnt ""
        accessorFunction = {}
        window.questionCache[name] = $(question)
        

        # cache accessor function
        $qC = window.questionCache[name]
        selects = $("select[name=#{name}]", $qC)
        if selects.length is 0
          inputs  = $("input[name=#{name}]", $qC)
          if inputs.length isnt 0
            type = inputs[0].getAttribute("type") 
            isCheckable = type is "radio" or type is "checkbox"
            if isCheckable
              do (name, $qC) -> accessorFunction = -> $("input:checked", $qC).safeVal()
            else
              do (inputs) -> accessorFunction = -> inputs.safeVal()
          else # inputs is 0
            do (name, $qC) -> accessorFunction = -> $(".textarea[name=#{name}]", $qC).safeVal()

        else # selects isnt 0
          do (selects) -> accessorFunction = -> selects.safeVal()

        window.getValueCache[name] = accessorFunction

    window.keyCache = _.keys(questionCache)





  # not used?
  currentKeyExistsInResultsFor: (question) ->
    Coconut.resultCollection.any (result) =>
      @result.get(@key) == result.get(@key) and result.get('question') == question

  repeat: (event) ->
    button = $(event.target)
    newQuestion = button.prev(".question").clone()
    questionID = newQuestion.attr("data-group-id")
    questionID = "" unless questionID?

    # Fix the indexes
    for inputElement in newQuestion.find("input")
      inputElement = $(inputElement)
      name = inputElement.attr("name")
      re = new RegExp("#{questionID}\\[(\\d)\\]")
      newIndex = parseInt(_.last(name.match(re))) + 1
      inputElement.attr("name", name.replace(re,"#{questionID}[#{newIndex}]"))

    button.after(newQuestion.add(button.clone()))
    button.remove()

  getLocation: (event) ->
    question_id = $(event.target).closest("[data-question-id]").attr("data-question-id")
    $("##{question_id}-description").val "Retrieving position, please wait."
    navigator.geolocation.getCurrentPosition(
      (geoposition) =>
        _.each geoposition.coords, (value,key) ->
          $("##{question_id}-#{key}").val(value)
        $("##{question_id}-timestamp").val(moment(geoposition.timestamp).format(Coconut.config.get "datetime_format"))
        $("##{question_id}-description").val "Success"
        @save()
        $.getJSON "http://api.geonames.org/findNearbyPlaceNameJSON?lat=#{geoposition.coords.latitude}&lng=#{geoposition.coords.longitude}&username=mikeymckay&callback=?", null, (result) =>
          $("##{question_id}-description").val parseFloat(result.geonames[0].distance).toFixed(1) + " km from center of " + result.geonames[0].name
          @save()
      (error) ->
        $("##{question_id}-description").val "Error: #{error}"
      {
        frequency: 1000
        enableHighAccuracy: true
        timeout: 30000
        maximumAge: 0
      }
    )

# jquery helpers

( ($) -> 

  $.fn.scrollTo = (speed = 500, callback) ->
    try
      $('html, body').animate {
        scrollTop: $(@).offset().top + 'px'
        }, speed, null, callback
    catch e
      console.log "error", e
      console.log "Scroll error with 'this'", @

    return @


  $.fn.safeVal = () ->
    if @is(":visible")
      return ( @val() || '' ).trim()
    else
      return null


)($)
