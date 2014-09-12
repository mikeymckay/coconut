require 'rubygems'
require 'couchrest'
require 'pp'

@db = CouchRest.database("http://localhost:5984/zanzibar")
#@db = CouchRest.database("http://coconut.zmcp.org/zanzibar")

docs_to_delete = []

puts "Getting data"
last_id = ""
data = []
@db.view("zanzibar/cases", {:limit=>"25000", :include_docs=>'true', :descending=>'false' })['rows'].each do |row|
  print "."
  id = row['key']
  last_id = id unless last_id

  if id != last_id
    complete_candidate = data.pop()
    if complete_candidate and complete_candidate['complete'] == "true"
#      puts "Complete:\n#{complete_candidate}"
      candidate_for_removal = data.shift()
      while candidate_for_removal and candidate_for_removal['complete'].nil?
#        puts "Removal item:\n#{candidate_for_removal}"
        candidate_for_removal["_deleted"] = true
        docs_to_delete.push candidate_for_removal
        candidate_for_removal = data.shift()
      end
      data = []
    end
  end

  if row['doc']['question'] == "Case Notification"
    if row['doc']['complete'] == "true"
#      puts "complete"
      data.push row['doc']
    else
#      puts "not complete"
      data.unshift row['doc']
    end
  end
  last_id = id
  #@db.save_doc(ussd_row['doc'])
end

puts docs_to_delete.length
@db.bulk_delete docs_to_delete
