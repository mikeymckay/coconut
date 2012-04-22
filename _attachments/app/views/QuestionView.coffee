class QuestionView extends Backbone.View
  initialize: ->
    Coconut.resultCollection ?= new ResultCollection()

  el: $('#content')

  render: =>
    @el.html "
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
    @updateCheckboxes()
    tagSelector = "input[name=Tags],input[name=tags]"
    $(tagSelector).tagit
      availableTags: [
        "complete"
      ]
      onTagChanged: ->
        $(tagSelector).trigger('change')
    _.each $("input[data-autocomplete-options]"), (element) ->
      element = $(element)
      element.autocomplete
        source: element.attr("data-autocomplete-options").split(/, */)
    _.each $("input[type='autocomplete from previous entries']"), (element) ->
      element = $(element)
      element.autocomplete
        source: document.location.pathname.substring(0,document.location.pathname.indexOf("index.html")) + "_list/values/byValue?key=\"#{element.attr("name")}\""

  events:
    "change #question-view input[type=checkbox]": "updateCheckboxes"
    "change #question-view input": "save"
    "change #question-view select": "save"
    "click #question-view button:contains(+)" : "repeat"

  updateCheckboxes: ->
    $('input[type=checkbox]:checked').siblings("label").find("span").html "&#x2611;"
    $('input[type=checkbox]').not(':checked').siblings("label").find("span").html "&#x2610;"

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
        result = "
          <div class='question'>#{
            "<label type='#{question.type()}' for='#{question_id}'>#{question.label()} <span></span></label>" unless question.type().match(/hidden/)
          }
        "

        result +=
          switch question.type()
            when "textarea"
              "<textarea name='#{name}' id='#{question_id}'>#{question.value()}</textarea>"
            when "select"
              "
                <select name='#{name}'>#{
                  _.map(question.get("select-options").split(/, */), (option) ->
                    "<option>#{option}</option>"
                  ).join("")
                }
                </select>
              "
            when "radio"
              _.map(question.get("radio-options").split(/, */), (option,index) ->
                "
                  <label for='#{question_id}-#{index}'>#{option}</label>
                  <input type='radio' name='#{name}' id='#{question_id}-#{index}' value='#{option}'/>
                "
              ).join("")
            when "checkbox"
                "<input style='display:none' name='#{name}' id='#{question_id}' type='checkbox' value='true'></input>"
            when "autocomplete from list"
                "<input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}' data-autocomplete-options='#{question.get("autocomplete-options")}'></input>"
            when "autocomplete from previous entries"
                "<input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}'></input>"
            else
                "<input name='#{name}' id='#{question_id}' type='#{question.type()}' value='#{question.value()}'></input>"



        result += "
          </div>
        "
        return result + repeatable
      else
        newGroupId = question_id
        newGroupId = newGroupId + "[0]" if question.repeatable()
        return "<div data-group-id='#{question_id}' class='question group'>" + @toHTMLForm(question.questions(), newGroupId) + "</div>" + repeatable
    ).join("")
