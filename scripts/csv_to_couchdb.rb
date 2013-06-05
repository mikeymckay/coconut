require 'rubygems'
require 'rest-client'
require 'json'
require 'csv'

url = "http://localhost:5984/coconut-clinic/_bulk_docs"

['tblDemography','tblSTI'].each do |table_name|

  docs = { "docs" => []}
  puts "\nProcessing #{table_name}"

  CSV.read("./#{table_name}.txt", "r:ISO-8859-1", :headers => true).each_with_index do |row,i|
    row["source"] = table_name
    row["_id"] = "#{table_name}-#{"%05d" % i}"
    row["collection"] = "imported result"
    docs["docs"].push row.to_hash
    print "." if i % 100 == 0
    if i % 1000 == 0
      RestClient.post(url, docs.to_json, :content_type => :json, :accept => :json)
      docs = { "docs" => []}
      print ">"
    end
  end
  

  if docs['docs'].length != 0
    RestClient.post(url, docs.to_json, :content_type => :json, :accept => :json)
    print ">"
  end
  

end
