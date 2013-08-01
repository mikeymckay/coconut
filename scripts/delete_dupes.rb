require 'rubygems'
require 'couchrest'
require 'pp'

@db = CouchRest.database("http://coconut.zmcp.org/zanzibar")

index = 0
last_name = ""
last_saved_doc_id = ""

@db.view('zanzibar/duplicateIdentifier')['rows'].each do |row|
  
  (id,name,value) = row["id"],row["key"],row["value"]
  if last_name == name
    current_doc = @db.get(id)
    puts
    puts "Deleting"
    pp current_doc
    puts "because we kept"
    pp @db.get(last_saved_doc_id)
    #current_doc.destroy(true)
  else
    print "."
    last_saved_doc_id = id
  end
  last_name = name
  @db.bulk_delete() if ((index+=1) % 300) == 0
end
@db.bulk_delete()
