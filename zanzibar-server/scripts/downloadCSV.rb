#! /usr/bin/env ruby
require 'rubygems'
require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'rest-client'
require 'json'

$configuration = JSON.parse(IO.read("configuration.json"))

save_directory = "/tmp/csv"
zip_file = "#{save_directory}.zip"
# Clean it out
`rm -rf #{save_directory}/*`
`rm #{zip_file}`

Capybara.register_driver :chrome do |app|
  profile = Selenium::WebDriver::Chrome::Profile.new
  profile["download.default_directory"] = save_directory
  Capybara::Selenium::Driver.new(app, :browser => :chrome, :profile => profile)
end

Capybara.default_driver = Capybara.javascript_driver = :chrome

Capybara.run_server = false
Capybara.current_driver = :chrome
Capybara.app_host = 'http://coconut.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
Capybara.default_wait_time = 60
Capybara::Screenshot.autosave_on_failure = false
Capybara.save_and_open_page_path = "/tmp"

def hide_everything_except(id)
  page.execute_script("$('##{id}').siblings().hide();$('##{id}').parents().siblings().hide();$('div[data-role=page]').css('min-height','')")
end

include Capybara::DSL
visit('#login')
fill_in 'username', :with => $configuration['report_user']
fill_in 'password', :with => $configuration['report_user_password']
click_button 'Login'
page.find_by_id("reportContents") #Wait for successful login

"Case Notification, Facility, Household, Household Members".split(/, */).each do |question_type|
  visit("#csv/#{question_type}/startDate/2012-09-01/endDate/2013-08-30")
  puts "Retrieving #{question_type}"
  sleep 1
  click_link 'csv'
  puts "Saved: #{question_type}"
end

`zip #{zip_file} #{save_directory}/*`
puts "Saved #{zip_file}"
