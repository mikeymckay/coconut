#! /usr/bin/env ruby
require 'rubygems'
require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'json'
require 'rest-client'
require 'trollop'

# Note had to add the following to make this work in chrome to 
# EDITED: /var/lib/gems/1.9.1/gems/selenium-webdriver-2.33.0/lib/selenium/webdriver/chrome/service.rb:20
#path = "/usr/local/bin/chromedriver"
#path or raise Error::WebDriverError, MISSING_TEXT


$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

opts = Trollop::options do
  opt :headless, "Need this for servers not running X"
  opt :send_to, "REQUIRED. Comma separated (no spaces) list of email addresses", :type => :string
end

if opts.send_to.nil?
  puts "--send-to is required"
  exit
end

if opts.headless
  require 'headless'
  headless = Headless.new
  at_exit do
    headless.destroy
  end
  headless.start
end

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end


Capybara.run_server = false
Capybara.current_driver = :selenium
Capybara.app_host = 'http://digitalocean.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://coconut.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
Capybara.default_wait_time = 60
Capybara::Screenshot.autosave_on_failure = false
Capybara.save_and_open_page_path = "/tmp"

def hide_everything_except(id)
  page.find_by_id(id)  #Makes sure capybara waits
  page.execute_script("$('##{id}').siblings().hide();$('##{id}').parents().siblings().hide();$('div[data-role=page]').css('min-height','')")
end

def remove_everything_except(id)
  page.find_by_id(id)  #Makes sure capybara waits
  hide_everything_except(id)
  page.execute_script("$(':hidden').remove()")
end

def get_element_html(id)
  page.find_by_id(id)  #Makes sure capybara waits
  page.evaluate_script("$('##{id}').html()")
end

include Capybara::DSL

def login
  visit('#login')
  fill_in 'username', :with => $configuration['report_user']
  fill_in 'password', :with => $configuration['report_user_password']
  click_button 'Login'
  page.find_by_id("reportContents") #Wait for successful login
end

def daily_alert_check
  visit('#reports/reportType/alerts')
  if get_element_html("hasAlerts").match(/Report finished, alerts found./)
    return get_element_html("alerts")
  else
    return nil
  end
end

def send_email (recipients, html, attachmentFilePaths = [])
  #RestClient.post "https://api:#KEY/v2/coconut.mailgun.org/messages",
  RestClient.post "https://#{$configuration["mailgun_login"]}@api.mailgun.net/v2/coconut.mailgun.org/messages",
    :from => "mmckay@rti.org",
    :to => recipients.join(","),
    :subject => "Coconut Surveillance Alerts",
    :text => "The non html version",
    :html => html,
    :attachment => attachmentFilePaths.map{|path| File.open(path)}
end

login()
puts "Logged in"
puts "Getting alerts"
alerts = daily_alert_check()
if alerts.nil?
  puts "No alerts found"
else
  puts "Alerts found, sending email to: #{opts.send_to}"
  send_email(opts.send_to.split(","),alerts) unless alerts.nil?
end
puts "Done"
