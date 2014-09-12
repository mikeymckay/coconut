require 'rubygems'
require 'couchrest'
require 'pp'
require 'rest-client'
#RestClient.log = 'stdout'

source = "http://coconutsurveillance:zanzibar@coconut.zmcp.org:5984/zanzibar"
target = "http://admin:password@localhost:5984/zanzibar"

source = CouchRest.database(source)
target = CouchRest.database(target)

docsToReplicate = []

puts "Getting list of all results"

#docsToReplicate.concat(source.view('zanzibar/results')['rows'].map{|result|
#docsToReplicate.concat(source.view('zanzibar/results', {:limit => 200})['rows'].map{|result|
#docsToReplicate.concat(source.view('zanzibar/byCollection', {:limit => 200, :key => "result"})['rows'].map{|result|
#  print "."
#  result['id']
#})
puts "Results: #{docsToReplicate.length}"


puts "Getting list of all facility weekly reports"

docsToReplicate.concat(source.view('zanzibar/weeklyDataBySubmitDate')['rows'].map{|result|
  print "."
  result['id']
})
puts "Results: #{docsToReplicate.length}"

puts "Getting list of all notifications"

#docsToReplicate.concat(source.view('zanzibar/notifications')['rows'].map{|result|
#docsToReplicate.concat(source.view('zanzibar/notifications', {:limit => 200})['rows'].map{|result|
#  print "."
#  result['id']
#})

#puts "Getting list of all application docs"
#docsToReplicate.concat(source.view('zanzibar/docIDsForUpdating')['rows'].map{|result|
#  print "."
#  puts result
#  if result["id"].match(/user/)
#    result['id']
#  else
#    nil
#  end
#})


while (docsToReplicate.length > 0) do
#  puts docsToReplicate
#  puts docsToReplicate.length
  docs = docsToReplicate.compact.pop(500)
  begin
    puts target.replicate_from(source, false, true, docs)
  rescue
    puts "Trying again in 5 s"
    sleep 5
    begin
      puts target.replicate_from(source, false, true, docs)
    rescue
      puts "...And again in 10s"
      sleep 10
      begin
        puts target.replicate_from(source, false, true, docs)
      rescue
        puts "FAILED, giving up for these docs: #{docs}"
      end
    end
  end

  #puts RestClient.post("#{target}/_replicate", {:content_type => :json}, :params => {:source => source, :target => 'zanzibar', :doc_ids => docsToReplicate.pop(100)}.to_json)
end
