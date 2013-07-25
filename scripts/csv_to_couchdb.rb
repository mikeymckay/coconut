require 'rubygems'
require 'rest-client'
require 'json'
require 'csv'

#url = "http://localhost:5984/coconut/_bulk_docs"
url = "http://ceshar.coconutclinic.org/coconut/_bulk_docs"

['tblDemography','tblSTI'].each do |table_name|

  docs = { "docs" => []}
  puts "\nProcessing #{table_name}"

  CSV.read("./#{table_name}.txt", "r:ISO-8859-1", :headers => true).each_with_index do |row,i|
    row["source"]     = table_name
    row["_id"]        = "#{table_name}-#{"%05d" % i}"
    #row["IDLabel"]    = row['IDLabel'].gsub(/-/, '')
    row["IDLabel"]    = row['IDLabel'].upcase
    row["collection"] = "imported result"

    newRow = {}
    row.each { |key, value|
      newRow[key] = value unless value.nil?
    }
    docs["docs"].push newRow.to_hash

    print "." if i % 100 == 0
    if i % 5000 == 0
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
