require 'rubygems'
require 'rest-client'
require 'json'

# type of documents to delete
docCollection = "imported result"

# Test locally first
host = "localhost:5984"
# host = "ceshhar.coconutclinic.org"

viewUrl = "http://#{host}/coconut/_design/coconut/_view/byCollection"
bulkDocsUrl = "http://#{host}/coconut/_bulk_docs"


puts "This will delete \"#{docCollection}\"s from #{host}. Are you sure? (y/n)"

confirm = STDIN.gets.chomp()
abort("that was a close one...") unless confirm.downcase == "y"

docs = { "docs" => []}
puts "\nRequesting imported results"

response = RestClient.get( viewUrl, :params => { :key => (docCollection).to_json } )
response = JSON.parse(response)

puts "\nFound #{response['rows']}"

docs = []

puts "\nPreparing to delete docs"

response['rows'].each_with_index { | row, index |

  print "." if i % 100 == 0
  print ">" if i % 5000 == 0

  docs.push({
    "_id"      => row['value']['_id'],
    "_rev"     => row['value']['_rev'],
    "_deleted" => true
  })

}

puts "\nDeleting documents on server"

response = RestClient.post( bulkDocsUrl, { :docs => docs }.to_json, :content_type => :json, :accept => :json )

response = JSON.parse(response)

puts "\nServer says"
puts response

