require 'rubygems'
require 'rest-client'
require 'json'
require 'csv'

['tblDemography','tblSTI'].each do |table_name|

  docs = { "docs" => []}
  puts "\nProcessing #{table_name}"

  CSV.read("./#{table_name}.txt", "r:ISO-8859-1", :headers => true).each_with_index do |row,i|
    row["source"] = "table_name"
    row["collection"] = "imported result"
    docs["docs"].push row.to_hash
    print "." if i % 100 == 0
  end
  url = "http://localhost:5984/coconut-clinic/_bulk_docs"
  puts "\nPosting #{docs["docs"].length} items to #{url}"

  JSON.parse RestClient.post(url, docs.to_json, :content_type => :json, :accept => :json)

end
