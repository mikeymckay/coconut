class User extends Backbone.Model
  url: "/user"

  username: ->
    @get("_id").replace(/^user\./,"")

  district: ->
    @get("district")

  passwordIsValid: (password) ->
    @get("password") is password

  isAdmin: ->
    _(@get("roles")).include "admin"

  hasRole: (role) ->
    _(@get("roles")).include role

  nameOrUsername: ->
    @get("name") or @username()

  login: ->
    User.currentUser = @
    $.cookie('current_user', @username())
    $("span#user").html @username()
    $('#district').html @get "district"
    $("a[href=#logout]").show()
    $("a[href=#login]").hide()
    if @isAdmin() then $("#manage-button").show() else $("#manage-button").hide()
    if @hasRole "reports"
      $("#top-menu").hide()
      $("#bottom-menu").hide()
      $.couch.db(Coconut.config.database_name()).saveDoc
        collection: "login"
        user: @username()
        date: moment(new Date()).format(Coconut.config.get "date_format")

  refreshLogin: ->
    @login()

User.isAuthenticated = (options) ->
  current_user_cookie = $.cookie('current_user')
  if current_user_cookie? and current_user_cookie isnt ""
    user = new User
      _id: "user.#{$.cookie('current_user')}"
    user.fetch
      success: =>
        user.refreshLogin()
        options.success(user)
      error: (error) ->
        # current user is invalid (should not get here)
        console.error "Could not fetch user.#{$.cookie('current_user')}: #{error}"
        options?.error()
  else
    # Not logged in
    options.error() if options.error?

User.logout = ->
  $.cookie('current_user',"")
  $("span#user").html ""
  $('#district').html ""
  $("a[href=#logout]").hide()
  $("a[href=#login]").show()
  User.currentUser = null

class UserCollection extends Backbone.Collection
  model: User
  url: '/user'
