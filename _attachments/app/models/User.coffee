class User extends Backbone.Model
  url: "/user"

class UserCollection extends Backbone.Collection
  model: User
  url: '/user'
