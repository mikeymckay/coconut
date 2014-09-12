require 'rubygems'
require 'couchrest'
require 'pp'

#@db = CouchRest.database("http://coconut.zmcp.org/zanzibar")
@db = CouchRest.database("http://localhost:5984/zanzibar")

index = 0
last_name = ""
last_saved_doc_id = ""

@db.view('zanzibar/rawNotificationsNotConvertedToCaseNotifications?include_docs=true')['rows'].each do |ussd_row|
  @db.view("zanzibar/cases", {:key=>ussd_row['doc']['caseid'], :include_docs=>'true'})['rows'].each do |row|
    if row['doc']['question'] == "Case Notification"
      puts "Found case notification"
      puts ussd_row['doc']
      ussd_row['doc']['hasCaseNotification'] = true
      @db.save_doc(ussd_row['doc'])
      puts "Saved: #{ussd_row['doc']}"
    else
      #puts "No case notification for case #{ussd_row['doc']['caseid']}"
    end
  end
end
