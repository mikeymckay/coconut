#! /usr/bin/env ruby
require 'rubygems'
require 'yaml'
#require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'json'
require 'rest-client'
require 'trollop'
require 'active_support/all'
require 'tempfile'
require 'capybara/poltergeist'


$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

$opts = Trollop::options do
  opt :send_to, "REQUIRED. Comma separated (no spaces) list of email addresses", :type => :string
end

#if $opts.send_to.nil?
#  puts "--send-to is required"
#  exit
#end

Capybara.run_server = false
Capybara.current_driver = :poltergeist
Capybara.app_host = 'http://coconut.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
Capybara.default_wait_time = 60
Capybara::Screenshot.autosave_on_failure = false
Capybara.save_and_open_page_path = "/tmp"

include Capybara::DSL

def login
  visit('#login')
  fill_in 'username', :with => $configuration['report_user']
  fill_in 'password', :with => $configuration['report_user_password']
  click_button 'Login'
  page.find_by_id("reportContents") #Wait for successful login
end

def url_from_options(options)
  options =
  {
    :startDate => Time.now().beginning_of_week(:monday).strftime("%Y-%m-%d"),
    :endDate => Time.now().end_of_week(:monday).strftime("%Y-%m-%d"),
    :reportType => "locations",
    :cluster => "off",
    :summaryField1 => "undefined",
    :region => "ALL",
    :district => "ALL",
    :constituan => "ALL",
    :shehia => "ALL",
    :mapWidth => "1000",
    :mapHeight => "2000"
  }.merge(options)

  "#reports/" + options.map { |option, value|
    "#{option}/#{value}"
  }.join("/") + "/"

end
  
def download_map(options)
  visit url_from_options(options)
  path = "/tmp/" + options.values.join("_") + ".png"
  sleep_time = 25
  puts "Waiting #{sleep_time} seconds for map to load: #{path}"
  sleep sleep_time
  puts "Creating #{path}"
  save_screenshot(path, :selector => '#map')
  return path
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

width = 2000
height = 4000

page.driver.resize(width + 100, height+100)
login()

islands = ["Pemba","Unguja"]
cluster_options = ["on","off"]
map_options = {
  :mapWidth => "#{width}px",
  :mapHeight => "#{height}px",
  :startDate => "2014-01-01",
  :endDate => "2014-04-31"
}

islands.each do |island|
  cluster_options.each do |cluster_option|
    download_map map_options.merge({:cluster => cluster_option, :showIsland => island})
  end
end


#puts "Sending email to: #{$opts.send_to}"
#send_email($opts.send_to.split(","),"Map",[map.path])
#puts "Done"
