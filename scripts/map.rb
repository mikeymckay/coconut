#! /usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'capybara-screenshot'
require 'json'
require 'rest-client'
require 'trollop'
require 'active_support/all'
require 'tempfile'

# Note had to add the following to make this work in chrome to 
# EDITED: /var/lib/gems/1.9.1/gems/selenium-webdriver-2.33.0/lib/selenium/webdriver/chrome/service.rb:20
#path = "/usr/local/bin/chromedriver"
#path or raise Error::WebDriverError, MISSING_TEXT


$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

$opts = Trollop::options do
  opt :headless, "Need this for servers not running X"
  opt :send_to, "REQUIRED. Comma separated (no spaces) list of email addresses", :type => :string
end

if $opts.send_to.nil?
  puts "--send-to is required"
  exit
end

if $opts.headless
  require 'headless'
  headless = Headless.new({:dimensions => "5000x5000x24"})
  at_exit do
    headless.destroy
  end
  headless.start
end

Capybara.register_driver :selenium do |app|

  caps = Selenium::WebDriver::Remote::Capabilities.chrome("chromeOptions" => {"args" => [ "start-maximized" ]})

  Capybara::Selenium::Driver.new(app, {:browser => :chrome, :desired_capabilities => caps})
end


Capybara.run_server = false
Capybara.current_driver = :selenium
Capybara.app_host = 'http://digitalocean.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://coconut.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
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
  `rm -f ~/Downloads/map.png`
  visit url_from_options(options)
  puts url_from_options(options)
  sleep 10
  click_button 'Download Map'
  sleep 10
  file = Tempfile.new(['map','.png'])
  `mv ~/Downloads/map.png #{file.path}`
  puts screenshot_and_save_page[:image]
  return file
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


puts `date`
login()
puts "Logged in"
puts "Getting map"
map = download_map({:showIsland => "Pemba"})
puts "Sending email to: #{$opts.send_to}"
send_email($opts.send_to.split(","),"Map",[map.path])
puts "Done"
