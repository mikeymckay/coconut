root = ::File.dirname(__FILE__)
require ::File.join( root, 'app' )

disable :run, :reload
set :enviroment, :development

run Sinatra::Application
