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
require 'trollop'

$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

opts = Trollop::options do
  opt :start_date, "REQUIRED. Start date", :type => :string
  opt :end_date, "REQUIRED. End date", :type => :string
end

if opts.start_date.nil? or opts.end_date.nil?
  puts "--start-date and --end-date are required"
  exit
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, 
    :timeout => 500,
    :js_errors => false
  )
end


Capybara.run_server = false
Capybara.current_driver = :poltergeist
Capybara.app_host = 'http://coconut.zmcp.org/zanzibar/_design/zanzibar/index.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index-dev.html'
#Capybara.app_host = 'http://localhost:5984/zanzibar/_design/zanzibar/index.html'
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

def spreadsheet(start_date,end_date,question)
  url = "#reports/startDate/#{start_date}/endDate/#{end_date}/reportType/csv/question/#{URI::encode question}"
  puts "Visiting: #{url}"
  visit(url)
  page.has_css?("#finished")
  file = Tempfile.new ["#{question}-#{start_date}-#{end_date}-",".csv"]
  file.write page.text.gsub("--EOR--","\r\n")
  return file
end

def spreadsheets(start_date,end_date)
  url = "#reports/startDate/#{start_date}/endDate/#{end_date}/reportType/csv"
  puts "Visiting: #{url}"
  visit(url)
  puts "Waiting for page to add finished span"
  page.has_css?("#finished")
  "USSDNotification,CaseNotification,Facility,Household,HouseholdMembers".split(/,/).map do |question|
    print "."
    file = Tempfile.new ["#{question}-#{start_date}-#{end_date}-",".csv"]
    file.write page.find(:css,"##{question}").text.gsub("--EOR--","\r\n").gsub(/^ /,"")
    file
  end
end

start_date = opts.start_date
end_date = opts.end_date

login()
puts "Logged in"
puts "Getting spreadsheet"
#csv_files = "USSD Notification,Case Notification,Facility,Household,Household Members".split(/,/).map do |question|
#  spreadsheet(start_date,end_date,question)
#end
csv_files = spreadsheets(start_date,end_date)
csv_files_paths = csv_files.map{|file|"\"#{file.path}\""}.join(" ")
zip_file = Tempfile.new "coc-surv-#{start_date}-#{end_date}"
puts `zip --junk-paths #{zip_file.path}.zip #{csv_files_paths}`
csv_files.each{|file|file.close(true)}
puts zip_file.path + ".zip"
