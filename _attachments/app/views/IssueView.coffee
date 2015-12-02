class IssueView extends Backbone.View
  el: '#content'

  events:
    "click button#edit" : "edit"
    "click button#save" : "save"

  render: =>
    @$el.html "
      <style>
      label { display: inline-block; width: 140px; text-align: right; }


      </style>

    "

    if @issue?
      console.log @issue
      @$el.append "
        <div style='display:hidden' id='message'></div>
        <h1>Issue: #{@issue.Description}</h1>
        #{
          if @issue["Threshold Description"] then "<h2>Threshold:#{@issue["Threshold Description"]}</h2>" else ""
        }

        <div id='responsibility'>
          <ul>
            #{
              if @issue["Assigned To"]?
                _(Issue.commonProperties).map (property) =>
                  return "" if property is "Description"
                  if property is "Assigned To"
                    "
                      <li id='assignedToValue'>
                        #{property}: #{Users.find({id: @issue["Assigned To"]}).nameOrUsernameWithDescription()}
                      </li>
                    "

                  else
                    "<li>#{property}: #{@issue[property]}</li>"
                .join ""
              else
                "Issue not yet assigned."
            }
          </ul>
          <button id='edit' type='button'>Edit</button>
        </div>

        <ul id='links'></ul>
      "

      if @issue.Links?
        $("ul#links").append _(@issue.Links).map( (link) =>
          linkText = link
          if linkText.match "show/case"
            linkText = linkText.replace("show/case/","").replace("#", "Case: ").replace(/\//," Household Member/Neighbor: ").replace(/Neighbor: (.*)/, (id) -> "Neighbor: ...#{id.substr(id.length - 3)}")
          "<li><a href='#{link}'>#{linkText}</li>"
        ).join("")

    else
      @$el.append "<h1>New Issue</h1>"
      @$el.append @issueForm()

  issueForm: => "
    <div>
      <label for='description'>Description</label>
      <textarea name='description'>#{@issue?.Description || ""}</textarea>
    </div>

    <div>
      <label for='assignedTo'>Assigned To</label>
      <select name='assignedTo'>
        <option></option>
        #{
          Users.map (user) =>
            userId = user.get "_id"
            "<option value='#{userId}' #{if @issue?["Assigned To"] is userId then "selected='true'" else ""}>
              #{user.nameOrUsernameWithDescription()}
             </option>"
          .join ""
        }
      </select>
    </div>

    <div>
      <label for='actionTaken'>Action Taken</label>
      <textarea name='actionTaken'>#{@issue?['Action Taken'] || ""}</textarea>
    </div>

    <div>
      <label for='solution'>Solution</label>
      <textarea name='solution'>#{@issue?['Solution'] || ""}</textarea>
    </div>

    <div>
      <label for='dateResolved'>Date Resolved</label>
      <input type='date' name='dateResolved' #{
        if @issue?['Date Resolved']
          "value = '#{@issue['Date Resolved']}'"
        else ""
      }
    </div>
    <div>
      <button id='save'>Save</button>
    </div>
    </input>
  "

  edit : =>
    $("#responsibility").html @issueForm()

  save: =>
    description = $("[name=description]").val()
    if description is ""
      $("#message").html("Issue must have a description to be saved")
      .show()
      .fadeOut(10)
      return

    if not @issue?
      dateCreated = moment().format("YYYY-MM-DD HH:mm:ss")

      @issue = {
        _id: "issue-#{dateCreated}-#{description.substr(0,10)}"
        "Date Created": dateCreated
      }

    @issue["Updated At"] = [] unless @issue["Updated At"]
    @issue["Updated At"].push moment().format("YYYY-MM-DD HH:mm:ss")
    @issue.Description = description
    @issue["Assigned To"] = $("[name=assignedTo]").val()
    @issue["Action Taken"] = $("[name=actionTaken]").val()
    @issue.Solution = $("[name=solution]").val()
    @issue["Date Resolved"] = $("[name=dateResolved]").val()

    Coconut.database.saveDoc @issue,
      error: (error) ->
        $("#message").html("Error saving issue: #{JSON.stringify error}")
        .show()
        .fadeOut(10000)
      success: =>
        Coconut.router.navigate "#show/issue/#{@issue._id}"
        @render()
        $("#message").html("Issue saved")
        .show()
        .fadeOut(2000)
