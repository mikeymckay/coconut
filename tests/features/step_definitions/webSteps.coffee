# features/step_definitions/myStepDefinitions.js

myStepDefinitionsWrapper = () ->
  @World = require("../support/world.coffee").World; # overwrite default World constructor

  @Given /^I am at (.*)$/, (url,callback) ->
    @visit url, callback

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
    # Check if we need to do a password lookup (to keep passwords out of git)
    passwordRegEx = text.match(/PASSWORD:(.*)/)
    text = @passwords[passwordRegEx[1]] if passwordRegEx?
    @browser.fill(target, text)
    callback()

  @When /^I press (.+)$/, (target,callback) ->
    @browser.pressButton target, callback

  @When /^I (click|touch) (.+)$/, (target,callback) ->
    @browser.clickLink target, callback

  @Then /^dump page$/, (callback) ->
    console.log @text()
    callback()



module.exports = myStepDefinitionsWrapper
