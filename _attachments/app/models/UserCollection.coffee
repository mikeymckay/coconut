class UserCollection extends Backbone.Collection
  model: User
  url: '/user'

  district: (userId) ->
    userId = "user.#{userId}" unless userId.match(/^user\./)
    @get(userId).get("district")

Users = new UserCollection()
Users.fetch()
