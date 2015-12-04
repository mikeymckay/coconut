
post '/valid_school' do
  (type,school_id,number_of_nets) = params["text"].split(/[, ]+/)

  return_this_when_invalid = {
    "status" => "invalid",
    "facility" => "invalid",
    "message" => "#{school_id} is not valid. Please send word nets then school id then the number of nets, e.g. 'nets 1003 65'"
  }.to_json

  return return_this_when_invalid if school_id.to_i%3 != 0


  school = JSON.parse(RestClient.get "http://schoolnet.couchappy.com/schoolnet/_design/schoolnet/_view/schoolsByUniqueID?key=#{school_id}", {:accept => :json})["rows"]

  @schoolnet_db = CouchRest.database("http://schoolnet.couchappy.com/schoolnet")

  puts school.inspect

  if school and school[0] and school[0]["value"].length == 6
    (name,village,ward,district,region,type) = school[0]["value"]

    doc_to_save = {
      "Name" => name,
      "Type" => type,
      "Village" => village,
      "Ward" => ward,
      "District" => district,
      "Region" => region,
      "Number of Nets" => number_of_nets,
      "School Id" => school_id,
      "Date" =>  Time.now.utc.iso8601,
      "Submitted By" => params["phone"],
      "Source" => "textit",
      "Flow" => "Confirming Nets"
    }

    puts doc_to_save.inspect

    @schoolnet_db.save_doc(doc_to_save)

    return {
      "status" => "valid",
      "message" => "Data saved: #{school[0]["value"].join(",")} has received #{number_of_nets}"
    }.to_json
  else
    return return_this_when_invalid
  end

end
