#! /usr/bin/env ruby
require 'rubygems'
require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'json'
require 'rest-client'

$configuration = JSON.parse(IO.read("configuration.json"))

if ARGV[0] == "--headless"
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
  page.execute_script("$('##{id}').siblings().hide();$('##{id}').parents().siblings().hide();$('div[data-role=page]').css('min-height','')")
end

include Capybara::DSL

def login
  visit('#login')
  fill_in 'username', :with => $configuration['report_user']
  fill_in 'password', :with => $configuration['report_user_password']
  click_button 'Login'
  page.find_by_id("reportContents") #Wait for successful login
end

def incidence_image
  visit('#reports/startDate/2013-06-12/endDate/2013-06-19/reportType/incidenceGraph/cluster/off/summaryField1/undefined/region/ALL/district/ALL/constituan/ALL/shehia/ALL')
  page.find_by_id("chart")
  hide_everything_except("chart")
  return screenshot_and_save_page[:image]
end


def map_image
  visit('#reports/startDate/2013-06-12/endDate/2013-06-19/reportType/locations/cluster/undefined/summaryField1/undefined/region/ALL/district/ALL/constituan/ALL/shehia/ALL')
  sleep 10
  page.find_by_id("map")
  hide_everything_except("map")
  return screenshot_and_save_page[:image]
end

def weekly_summary_html
  visit('#reports/reportType/weeklySummary/')
  page.find_by_id("alertsTable")
  hide_everything_except("alertsTable")

  #Inlines table styles removes hidden elements
  page.execute_script('
    _(["odd", "even"]).each(function(oddOrEven) {
      return _($("." + oddOrEven + " td")).each(function(td) {
        return $(td).attr("style", "" + ($(td).attr("style") || "") + "; background-color: " + ($("." + oddOrEven + " td").css("background-color")));
      });
    });

    /*
    $("[style=\'display:none\']").remove();
    $("[style=\'display:none;\']").remove();
    $("[style=\'display: none\']").remove();
    $("[style=\'display: none;\']").remove();
    */
    $(":hidden").remove()
  ')

  return page.find_by_id("alertsTable").html
end


def send_email (recipients, html, attachmentFilePaths = [])
  #RestClient.post "https://api:#KEY/v2/coconut.mailgun.org/messages",
  RestClient.post "https://#{$configuration["mailgun_login"]}@api.mailgun.net/v2/coconut.mailgun.org/messages",
    :from => "mmckay@rti.org",
    :to => recipients.join(","),
    :subject => "Coconupdates",
    :text => "The non html version",
    :html => html,
    :attachment => attachmentFilePaths.map{|path| File.open(path)}
end

login()
puts "Logged in"
incidence_image_path = incidence_image()
puts "Getting map"
map = map_image()
puts "Getting weekly summary"
send_email(["mikeymckay@gmail.com"],weekly_summary_html(),[incidence_image_path,map])
puts "Email sent"

sleep 30
