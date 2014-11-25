#! /usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'json'
require 'rest-client'
require 'trollop'
require 'active_support/all'
require 'capybara/poltergeist'


$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

$opts = Trollop::options do
  opt :send_to, "REQUIRED. Comma separated (no spaces) list of email addresses", :type => :string
end

if $opts.send_to.nil?
  puts "--send-to is required"
  exit
end

Capybara.run_server = false
Capybara.current_driver = :poltergeist
Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
Capybara.default_wait_time = 60
Capybara::Screenshot.autosave_on_failure = false
Capybara.save_and_open_page_path = "/tmp"

include Capybara::DSL

def hide_everything_except(id)
  page.execute_script("$('##{id}').siblings().hide();$('##{id}').parents().siblings().hide();$('div[data-role=page]').css('min-height','')")
end

def login
  visit('#login')
  fill_in 'username', :with => $configuration['report_user']
  fill_in 'password', :with => $configuration['report_user_password']
  click_button 'Login'
  page.find_by_id("reportContents") #Wait for successful login
end

def incidence_image()
  visit('#reports/reportType/incidenceGraph')
  page.find_by_id("chart")
  hide_everything_except("chart")
  return screenshot_and_save_page[:image]
end


def map_image(startDate,endDate)
  visit("#reports/startDate/#{startDate}/endDate/#{endDate}/reportType/locations/cluster/undefined/summaryField1/undefined/region/ALL/district/ALL/constituan/ALL/shehia/ALL")
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

start_date = Time.now().beginning_of_week(:monday).strftime("%Y-%m-%d")
end_date = Time.now().end_of_week(:monday).strftime("%Y-%m-%d")

puts "#{start_date} - #{end_date}"
puts `date`
login()
puts "Logged in"
incidence_image_path = incidence_image()
puts "Getting map"
map = map_image(start_date,end_date)
puts "Getting weekly summary"
puts "Sending email to: #{$opts.send_to}"
send_email($opts.send_to.split(","),weekly_summary_html(),[incidence_image_path,map])
puts "Done"
