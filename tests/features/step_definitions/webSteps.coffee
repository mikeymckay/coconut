# features/step_definitions/myStepDefinitions.js

myStepDefinitionsWrapper = () ->
  @World = require("../support/world.coffee").World; # overwrite default World constructor

  @Given /^I am at (.*)$/, (url,callback) ->
    # `this` is set to a new this.World instance.
    # i.e. you may use this.browser to execute the step:

    @visit url, callback

    # The callback is passed to visit() so that when the job's finished, the next step can
    # be executed by Cucumber.

  @Then /^I should see "(.*)"$/, (text, callback) ->
      if !@text().match(text)
        callback.fail new Error "Expected to see #{text}"
      else
        callback()

  @Then /^I should not see "(.*)"$/, (text, callback) ->
      if @text().match(text)
        callback.fail new Error "Expected to see #{text}"
      else
        callback()

  @Then /^I should not see "(.*)"$/, (text, callback) ->
      if @text().match(text)
        callback.fail new Error "Did not expect to see #{text}"
      else
        callback()

  @When /^I fill (.+) with (.+)$/, (target,text,callback) ->
    @browser.fill(target, text)
    callback()

  @When /^I press (.+)$/, (target,callback) ->
    @browser.pressButton target
    callback()

  @When /^I (click|touch) (.+)$/, (target,callback) ->
    @browser.clickLink target
    callback()

  @Then /^dump page$/, (callback) ->
    console.log @text()
    callback()



module.exports = myStepDefinitionsWrapper
