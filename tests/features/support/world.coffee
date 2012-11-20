# features/support/world.coffee

zombie = require('zombie')

World = (callback) ->
  this.browser = new zombie.Browser() # this.browser will be available in step definitions

  this.b = this.browser

  this.visit = (url, callback) ->
    this.browser.visit(url, callback)

  this.text = () ->
    return this.browser.text("body")

  callback() # tell Cucumber we're finished and to use 'this' as the world instance

exports.World = World
