class QuestionView extends Backbone.View
  initialize: ->
    Coconut.resultCollection ?= new ResultCollection()

  el: '#content'

  render: =>
    @$el.html "
      <div style='display:none' id='messageText'>
        Saving...
      </div>
      <div id='question-view'>
        <form>
          #{@toHTMLForm(@model)}
        </form>
      </div>
    "
    js2form($('form').get(0), @result.toJSON())
    @$el.find("input[type=text],input[type=number],input[type='autocomplete from previous entries']").textinput()
    @$el.find('input[type=radio],input[type=checkbox]').checkboxradio()
    @$el.find('ul').listview()
    @$el.find('input[type=date]').datebox
      mode: "calbox"
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
        source = element.attr("data-autocomplete-options").split(/, */)
      else
        source = document.location.pathname.substring(0,document.location.pathname.indexOf("index.html")) + "_list/values/byValue?key=\"#{element.attr("name")}\""

      element.autocomplete
        source: source
        target: "##{element.attr("id")}-suggestions"
        callback: (event) ->
          element.val($(event.currentTarget).text())
          element.autocomplete('clear')

    $('input,textarea').attr("readonly", "true") if @readonly

  events:
    "change #question-view input": "save"
    "change #question-view select": "save"
    "click #question-view button:contains(+)" : "repeat"
    "click #question-view a:contains(Get current location)" : "getLocation"

  getLocation: (event) ->
    navigator.geolocation.getCurrentPosition(
      (geoposition) =>
        target = $(event.target)
        question_id = target.attr("data-question-id")
        _.each geoposition.coords, (value,key) ->
          $("##{question_id}-#{key}").val(value)
        $("##{question_id}-locationTimestamp").val(geoposition.timestamp)
        $("#location-message").html "Success"
        @save()
        $.getJSON "http://api.geonames.org/findNearbyPlaceNameJSON?lat=#{geoposition.coords.latitude}&lng=#{geoposition.coords.longitude}&username=mikeymckay&callback=?", null, (result) ->
          $("#location-message").html parseFloat(result.geonames[0].distance).toFixed(1) + " km from " + result.geonames[0].name + "(" + moment(new Date(geoposition.timestamp)).fromNow() + ")"
      ->
        $("#location-message").html "Error receiving location"
    )

  save: ->
    @result.save $('form').toObject(skipEmpty: false)
    $("#messageText").slideDown().fadeOut()

    @key = "MalariaCaseID"

    if @result.complete()
      # Check if the next level needs to be created
      Coconut.resultCollection.fetch
        success: =>
          switch(@result.get 'question')
            when "Case Notification"
              unless @currentKeyExistsInResultsFor 'Facility'
                result = new Result
                  question: "Facility"
                  MalariaCaseID: @result.get "MalariaCaseID"
                  FacilityName: @result.get "FacilityName"
                result.save()
            when "Facility"
              unless @currentKeyExistsInResultsFor 'Household'
                result = new Result
                  question: "Household"
                  MalariaCaseID: @result.get "MalariaCaseID"
                  HeadofHouseholdName: @result.get "HeadofHouseholdName"
                result.save()
            when "Household"
              unless @currentKeyExistsInResultsFor 'HouseholdMembers'
                _(@result.get "TotalNumberofResidentsintheHouseholdAvailableforInterview").times =>
                  result = new Result
                    question: "Household Members"
                    MalariaCaseID: @result.get "MalariaCaseID"
                    HeadofHouseholdName: @result.get "HeadofHouseholdName"
                  result.save()

  currentKeyExistsInResultsFor: (question) ->
    Coconut.resultCollection.any (result) =>
      @result.get(@key) == result.get(@key) and
      result.get('question') == question

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
        name = question.label().replace(/[^a-zA-Z0-9 -]/g,"").replace(/[ -]/g,"")
        question_id = question.get("id")
        if question.repeatable() == "true"
          name = name + "[0]"
          question_id = question.get("id") + "-0"
        if groupId?
          name = "group.#{groupId}.#{name}"

        return "
          <div class='question'>#{
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
              when "radio", "select"
                if @readonly
                  "<input name='#{name}' type='text' id='#{question_id}' value='#{question.value()}'></input>"
                else
                  options = question.get("radio-options") or question.get("select-options")
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
              when "autocomplete from list"
                "
                  <input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}' data-autocomplete-options='#{question.get("autocomplete-options")}'></input>
                  <ul id='#{question_id}-suggestions' data-role='listview' data-inset='true'/>
                "
              when "autocomplete from previous entries"
                "
                  <input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}'></input>
                  <ul id='#{question_id}-suggestions' data-role='listview' data-inset='true'/>
                "
              when "location"
                "
                <a data-question-id='#{question_id}'>Get current location</a>
                <span id='location-message'></span>
                #{
                  _.map(["latitude", "longitude", "accuracy", "altitude", "altitudeAccuracy", "heading", "locationTimestamp"], (field) ->
                    "<label for='#{question_id}-#{field}'>#{field}</label><input readonly='true' type='number' name='#{name}-#{field}' id='#{question_id}-#{field}'></input>"
                  ).join("")
                }
                "

              when "image"
                "<a>Get image</a>"
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
