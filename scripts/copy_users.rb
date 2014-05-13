require 'rubygems'
require 'rest-client'
require 'json'

# type of documents to delete
docCollection = "imported result"

# Test locally first
#host = "localhost:5984"
host = "ceshhar.coconutclinic.org"

usersToCopy = "http://#{host}/coconut-may12/_design/coconut/_view/byCollection?key=%22user%22"
destination = "http://#{host}/coconut/_bulk_docs"

docs = { "docs" => []}
puts "\nRequesting imported results"

#response = RestClient.get( usersToCopy, :params => { :key => "user", :include_docs => true} )
response = RestClient.get( usersToCopy)
user_docs = JSON.parse(response)['rows'].map do |row|
  row["value"]
end

response = RestClient.post( destination, { :docs => user_docs }.to_json, :content_type => :json, :accept => :json )

response = JSON.parse(response)

puts "\nServer says"
puts response

