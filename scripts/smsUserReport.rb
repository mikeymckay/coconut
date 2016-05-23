#! /usr/bin/env ruby
require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'json'
require 'rest-client'
require 'trollop'
require 'capybara/poltergeist'
require 'tempfile'
require 'open-uri'

$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))
$passwords_and_config = JSON.parse(IO.read(File.dirname(__FILE__) + "/passwords.json"))

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, 
    :timeout => 100
  )
end

$base_url = "http://localhost:5984/zanzibar"
#$design_doc_and_index ="_design/zanzibar/index.html"
$design_doc_and_index ="_design/zanzibar/index-dev.html"
$number_of_days = 7

Capybara.run_server = false
Capybara.current_driver = :poltergeist
Capybara.app_host = "#{$base_url}/#{$design_doc_and_index}"
Capybara.default_wait_time = 500
Capybara.save_and_open_page_path = "/tmp"

include Capybara::DSL

def login
  visit('#login')
  fill_in 'username', :with => $configuration['report_user']
  fill_in 'password', :with => $configuration['report_user_password']
  click_button 'Login'
  page.find_by_id("reportContents") #Wait for successful login
end

def username_to_name(username)
  JSON.parse(RestClient.get "#{$base_url}/user.#{username}")["name"] or username
end

def send_message(to,message)
  puts to
  puts message

  to = to.gsub(/^0/, "+255")

  RestClient.get "http://www.bongolive.co.tz/api/sendSMS.php", {
    :params  => {
      :destnum    => to,
      :message    => message
    }.merge($passwords_and_config["bongo_credentials"])
  }
end

def user_messages(user_analysis)
  user_analysis["dataByUser"].each do |username,analysis|
    first_name = username_to_name(username).gsub(/ .*/,"")
    message = ""
    if analysis["casesWithoutCompleteFacilityAfter24Hours"].length == 0 and analysis["casesWithoutCompleteHouseholdAfter48Hours"].length == 0 and analysis["cases"].length > 2
      praise = "GOOD JOB,GREAT WORK,EXCELLENT,WELL DONE".split(/,/).sample
      message = "#{first_name}, #{praise}! For past #{$number_of_days} days: #{analysis["cases"].length} case#{"s" unless analysis["cases"].length == 1} without any cases overdue."
    else
      message = "#{first_name}, for past #{$number_of_days} days: #{analysis["cases"].length} case#{"s" unless analysis["cases"].length == 1}, #{analysis["casesWithoutCompleteFacilityAfter24Hours"].length} missing facility after 24hrs, #{analysis["casesWithoutCompleteHouseholdAfter48Hours"].length} missing household after 48hrs"
    end

    if username.match(/^0/)
      send_message(username,message)
    end
  end
end



def admin_messages(user_analysis)
  {
    "Humphrey" => "0788074705",
    "Abdul" => nil,
    "Jeremiah" => "0688619263",
    "Wahida" => nil
  }.each do |first_name, phone_number|
    analysis = user_analysis["total"]
    message = ""
    if analysis["casesWithoutCompleteFacilityAfter24Hours"].length == 0 and analysis["casesWithoutCompleteHouseholdAfter48Hours"].length == 0 and analysis["cases"].length > 2
      praise = "GOOD JOB,GREAT WORK,EXCELLENT,WELL DONE".split(/,/).sample
      message = "#{first_name}, #{praise}! For past #{$number_of_days} days: #{analysis["cases"].length} case#{"s" unless analysis["cases"].length == 1} without any cases overdue. Med. time: #{analysis["medianTimeFromSMSToCompleteHousehold"]} http://ow.ly/EDZEB"
    else
      message = "#{first_name}, #{analysis["cases"].length} case#{"s" unless analysis["cases"].length == 1} in past #{$number_of_days} days, #{analysis["casesWithoutCompleteFacilityAfter24Hours"].length} missing facility after 24hrs, #{analysis["casesWithoutCompleteHouseholdAfter48Hours"].length} missing household after 48hrs. Med. time: #{analysis["medianTimeFromSMSToCompleteHousehold"]} http://ow.ly/EDZEB"
    end

    if phone_number
      send_message(phone_number,message)
    end

  end
end

puts DateTime.now

login()

start_date = (Date.today - $number_of_days).strftime
end_date = Date.today.strftime

visit("#raw/userAnalysis/#{start_date}/#{end_date}")

user_analysis =  JSON.parse(find_by_id("json").text)

user_messages(user_analysis)

admin_messages(user_analysis)


