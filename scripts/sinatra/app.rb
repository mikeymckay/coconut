require 'rubygems'
require 'sinatra'
require 'couchrest'
require 'rest-client'
require 'cgi'
require 'json'
require 'net/http'
require 'yaml'
require 'axlsx'
require 'csv'
require 'fuzzy_match'
require 'securerandom'
require 'date'
require 'time'

$passwords_and_config = JSON.parse(IO.read("passwords_and_config.json"))

require_relative  'methods'
require_relative  'routes_spreadsheet'
require_relative  'routes_textit'

# Can remove once they are not longer used
require_relative  'routes_medic_mobile'
require_relative  'routes_schoolnet'
