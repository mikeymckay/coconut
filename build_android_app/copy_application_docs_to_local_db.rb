require 'rubygems'
require 'couchrest'

cloud_db_url = 'http://coconut.zmcp.org/zanzibar'
local_db_url = 'http://localhost:5984/zanzibar'

@cloud_db = CouchRest.database(cloud_db_url)
@local_db = CouchRest.database(local_db_url)

@cloud_db.view('zanzibar/docIDsForUpdating', {:include_docs => true})['rows'].each do |doc|
  puts doc['id']
  begin
    @local_db.save_doc(doc['doc'])
  rescue
    puts "Failed to load #{doc['id']}"
  end
end

