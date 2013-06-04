window.SkipTheseWhen = ( argQuestions, result ) ->
  questions = []
  argQuestions = argQuestions.split(/\s*,\s*/)
  for question in argQuestions
    questions.push $(".question[data-question-name=#{question}]")
  disabledClass = "disabled_skipped"

  for question in questions
    if result
      question.addClass disabledClass
    else
      question.removeClass disabledClass


window.ResultOfQuestion = ( name ) ->
  return result.val() if (result = $(".question select[name=#{name}]")).length isnt 0
  if (result = $(".question input[name=#{name}]")).length isnt 0
    if result.attr("type") is "radio" or result.attr("type") is "checkbox"
      result = $(".question input[name=#{name}]:checked")
    return result.val()
  return result.val() if (result = $(".question textarea[name=#{name}]")).length != 0

class QuestionView extends Backbone.View

  initialize: ->
    Coconut.resultCollection ?= new ResultCollection()

  el: '#content'

  triggerChangeIn: (names) ->
    for name in names
      $(".question[data-question-name=#{name}] input, .question[data-question-name=#{name}] select, .question[data-question-name=#{name}] textarea").each (index, element) =>
        event = target : element
        @actionOnChange event

  render: =>
    @$el.html "
      <div style='position:fixed; right:5px; color:white; background-color: #333; padding:20px; display:none; z-index:10' id='messageText'>
        Saving...
      </div>
      <div id='question-view'>
        <form>
          #{@toHTMLForm(@model)}
        </form>
      </div>
    "

    # for first run
    @updateSkipLogic()
    
    # skipperList is a list of questions that use skip logic in their action on change events
    skipperList = []

    _.each @model.get("questions"), (question) =>

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

    $("input[name=complete]").closest("div.question").prepend "
        <div style='background-color:yellow' id='validationMessage'></div>
      "
    $('input,textarea').attr("readonly", "true") if @readonly

  events:
    "blur #question-view input"      : "onChange"
    "change #question-view input"    : "onChange"
    "change #question-view select"   : "onChange"
    "change #question-view textarea" : "onChange"
    "click #question-view button:contains(+)" : "repeat"
    "click #question-view a:contains(Get current location)" : "getLocation"

  onChange: (event) ->
    eventStamp = $(event.target).attr("id") + "-" + event.type
    return if eventStamp == @oldStamp
    @oldStamp = eventStamp
    @save()
    @updateSkipLogic()
    @actionOnChange(event)

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
    value = ResultOfQuestion(name)
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
    _($(".question")).each (question) ->

      question = $(question)

      skipLogicCode = question.attr("data-skip_logic")
      return if skipLogicCode is "" or not skipLogicCode?
      
      try
        result = CoffeeScript.eval.apply(@, [skipLogicCode])
      catch error
        name = ((/function (.{1,})\(/).exec(error.constructor.toString())[1])
        message = error.message
        alert "Skip logic error in question #{question.attr('data-question-id')}\n\n#{name}\n\n#{message}"

      id = question.attr('data-question-id')

      if result
        question.addClass "disabled_skipped"
      else
        question.removeClass "disabled_skipped"


  getLocation: (event) ->
    question_id = $(event.target).closest("[data-question-id]").attr("data-question-id")
    $("##{question_id}-description").val "Retrieving position, please wait."
    navigator.geolocation.getCurrentPosition(
      (geoposition) =>
        _.each geoposition.coords, (value,key) ->
          $("##{question_id}-#{key}").val(value)
        $("##{question_id}-timestamp").val(moment(geoposition.timestamp).format(Coconut.config.get "date_format"))
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

  validate: (result) ->
    $("#validationMessage").html ""
    _.each result, (value,key) =>
      $("#validationMessage").append @validateItem(value,key)

    _.chain($("input[type=radio]"))
    .map (element) ->
      $(element).attr("name")
    .uniq()
    .map (radioName) ->
      question = $("input[name=#{radioName}]").closest("div.question")
      required = question.attr("data-required") is "true"
      if required and not $("input[name=#{radioName}]").is(":checked")
        labelID = question.attr("data-question-id")
        labelText = $("label[for=#{labelID}]")?.text()
        $("#validationMessage").append "'#{labelText}' is required<br/>"

    unless $("#validationMessage").html() is ""
      $("input[name=complete]")?.prop("checked", false)
      return false
    else
      return true

  validateItem: (value, question_id) ->
    result = []
    question = $("[name=#{question_id}]")
    labelText = $("label[for=#{question.attr("id")}]")?.text()
    required = question.closest("div.question").attr("data-required") is "true"
    validation = unescape(question.closest("div.question").attr("data-validation"))
    if required and not value?
      result.push "'#{labelText}' is required (NA or 9999 may be used if information not available)"
    if validation != "undefined" and validation != null
      validationFunction = CoffeeScript.eval("(value) -> #{validation}", {bare:true})
      result.push validationFunction(value)
    result = _.compact(result)
    if result.length > 0
      return result.join("<br/>") + "<br/>"
    else
      return ""

  # We throttle to limit how fast save can be repeatedly called
  save: _.throttle( ->
    currentData = $('form').toObject(skipEmpty: false)

    # don't allow invalid results to be marked and saved as complete
    if currentData.complete and not @validate(currentData)
      return

    @result.save _.extend(
      # Make sure lastModifiedAt is always updated on save
      currentData
      {
        lastModifiedAt: moment(new Date())
          .format(Coconut.config.get "date_format")
        savedBy: $.cookie('current_user')
      }
    ),
      success: ->
        $("#messageText").slideDown().fadeOut()

    @key = "MalariaCaseID"

    # Update the menu
    Coconut.menuView.update()
  , 1000)

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

  toHTMLForm: (questions = @model, groupId) ->
    # Need this because we have recursion later
    questions = [questions] unless questions.length?
    _.map(questions, (question) =>

      if question.repeatable() == "true" then repeatable = "<button>+</button>" else repeatable = ""
      if question.type()? and question.label()? and question.label() != ""
        name = question.safeLabel()
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
            data-skip_logic='#{_.escape(question.skipLogic())}'
            data-action_on_change='#{_.escape(question.actionOnChange())}'

          >#{
            "<label type='#{question.type()}' for='#{question_id}'>#{question.label()} <span></span></label>" unless question.type().match(/hidden/)
          }
          #{
            switch question.type()
              when "textarea"
                "<input name='#{name}' type='text' id='#{question_id}' value='#{question.value()}'></input>"
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
                      <input type='radio' name='#{name}' id='#{question_id}-#{index}' value='#{option}'/>
                    "
                  ).join("")
              when "checkbox"
                if @readonly
                  "<input name='#{name}' type='text' id='#{question_id}' value='#{question.value()}'></input>"
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
