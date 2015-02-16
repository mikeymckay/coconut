class UsersView extends Backbone.View

  initialize: ->
    @userCollection = new UserCollection()

  el: '#content'

  events:
    "submit form#user": "save"
    "click .loadUser": "load"
    "click #cancel": "cancel"
    "click #new": "newUser"

  cancel: ->
    $("#edit-user").hide()

  newUser: ->
    $("input").val("")
    $("#edit-user").show()

  save: ->
    userData = $('form#user').toObject(skipEmpty: false)
    userData._id = "user." + userData._id
    userData.inactive = true if userData.inactive is 'on'
    userData.isApplicationDoc = true
    userData.district = userData.district.toUpperCase() if userData.district?
    userData.roles = _($("[name=role]:checked")).map (element) ->
      $(element).attr("value")
    user = new User
      _id: userData._id

    console.log user

    hideEditorUpdateTable = =>
      user.save userData,
        success: =>
          @render()
          $("#edit-user").hide()

    user.fetch
      success: =>
        hideEditorUpdateTable()
      error: =>
        hideEditorUpdateTable()

    return false

  load: (event) ->
    $("#edit-user").show()
    user = new User
      _id: $(event.target).closest("a").attr "data-user-id"
    user.fetch
      success: =>
        user.set
          _id: user.get("_id").replace(/user\./,"")
        js2form($('form#user').get(0), user.toJSON())
        for role in user.get "roles"
          $("[name=role][value=#{role}]").prop("checked", true)
    return false
  
  render: =>
    fields =  "_id,password,district,name,roles,comments".split(",")
    @$el.html "
      <div style='display:none' id='edit-user'>
        <h2>Create/edit users</h2>
        <ul>
          <li>DMSO's must have a username that corresponds to their phone number.</li>
          <li>If a DMSO is no longer working, mark their account as inactive to stop notification messages from being sent.</li>
        </ul>
        <form id='user'>
          #{
            _.map( fields, (field) ->
              "
              <label style='display:block' for='#{field}'>#{if field is "_id" then "Username" else field.humanize()}</label>
              <input id='#{field}' name='#{field}' type='text'></input>
              "
            ).join("")
          }
          <label style='display:block' for='inactive'>Inactive</label>
          <input id='inactive' name='inactive' type='checkbox'></input>
          <br/>
          <input type='submit' value='Save'></input>
          <button id='cancel' type='button'>Cancel</button>
        </form>
      </div>

      <h2>Click username to edit</h2>
      <button id='new' type='button'>Create new user</button>

      <br/>
      <br/>

      <table>
        <thead>
          <tr>
          #{
            fields.push "inactive"
            _.map( fields, (field) ->
              "<th>#{if field is "_id" then "Username" else  field.humanize()}</th>"
            ).join("")
          }
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    "


    @userCollection.fetch
      success: =>
        uniqueRolesForUsers = _(_(_(@userCollection.pluck("roles")).flatten()).uniq()).compact()
        $("input#roles").replaceWith(
          _(uniqueRolesForUsers).map (role) ->
            "<input name='role' type='checkbox' value='#{role}'>#{role}</input>"
          .join("")
        )
        @userCollection.sortBy (user) ->
          user.get "_id"
        .forEach (user) ->
          $("tbody").append "
            <tr>
              #{
                _.map(fields, (field) ->
                  data = user.get(field) || '-'
                  if field is "_id"
                    "<td><a class='loadUser' data-user-id='#{user.get "_id"}' href=''>#{data.replace(/user\./,"")}</a></td>"
                  else
                    "<td>#{data}</td>"
                ).join("")
              }
            </tr>
          "
        $("a").button()
        $('table').dataTable()
