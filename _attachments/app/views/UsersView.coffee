class UsersView extends Backbone.View

  initialize: ->
    @userCollection = new UserCollection()

  el: '#content'

  events:
    "submit form#user": "save"
    "click .loadUser": "load"

  save: ->
    userData = $('form#user').toObject(skipEmpty: false)
    userData._id = "user." + userData._id
    userData.inactive = true if userData.inactive is 'on'
    userData.isApplicationDoc = true
    userData.district = userData.district.toUpperCase() if userData.district?
    user = new User
      _id: userData._id
    user.fetch
      success: =>
        user.save userData,
          success: =>
            @render()
      error: =>
        user.save userData,
          success: =>
            @render()

    return false

  load: (event) ->
    user = new User
      _id: $(event.target).closest("a").attr "data-user-id"
    user.fetch
      success: =>
        user.set
          _id: user.get("_id").replace(/user\./,"")
        js2form($('form#user').get(0), user.toJSON())
    return false
  
  render: =>
    fields =  "_id,password,district,name,comments".split(",")
    @$el.html "
      <h2>Create/edit users</h2>
      <h3>Use phone number for username to enable SMS messages</h3>
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
        <input type='submit'></input>
      </form>

      <h2>Click username to edit</h2>

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
