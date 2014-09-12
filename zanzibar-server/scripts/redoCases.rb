require 'rubygems'
require 'couchrest'
require 'pp'

@db = CouchRest.database("http://coconut.zmcp.org/zanzibar")
#@db = CouchRest.database("http://localhost:5984/zanzibar")

"104400;104392;104380;104345;;104358;103807;103775;104346;104344;104343;104340;104336;104329;104300;104287;103834;104242;104213;104080;104073;104063".split(/;/).each do |caseid|

  @db.view("zanzibar/cases", {:key=>caseid, :include_docs=>'true'})['rows'].each do |row|
    if row['doc']['question'] == "Case Notification"
      puts "Deleting: \n#{row['doc']}"
      @db.delete_doc(row['doc'])
    end

    if row['doc']['hasCaseNotification'] == true
      row['doc']['hasCaseNotification'] = false
      @db.save_doc(row['doc'])
      puts "Saved: \n#{row['doc']}"
    end
  end
end
