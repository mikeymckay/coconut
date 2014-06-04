require 'rubygems'
require 'couchrest'
require 'cgi'
require 'json'
require 'net/http'
require 'rest_client'

@passwords = JSON.parse(IO.read("passwords.json"))

@db = CouchRest.database("http://coconut.zmcp.org/zanzibar")
@facilityHierarchy = JSON.parse(RestClient.get "#{@db}/Facility%20Hierarchy", {:accept => :json})["hierarchy"]

def districtByFacility(facility)
  @facilityHierarchy.each do |district,facilityData|
    if facilityData.map{|data| data["facility"]}.include?(facility) then
      return district
    end
  end
  return nil
end

def send_message(user,message)
  success = true
  phone_number = user["_id"].sub(/user\./,"").sub(/^0/,"255")
  message = CGI.escape(message)
  puts "Send '#{message}' message to #{phone_number} at #{Time.now}" 
  result = `curl -s -S -k -X GET "https://paypoint.selcommobile.com/bulksms/dispatch.php?msisdn=#{phone_number}&user=#{@passwords["username3"]}&password=#{@passwords["password3"]}&message=#{message}"`
  if result.match(/.*:.*:(.*)/) and Integer($1) < 20
    log_error("Only #{$1} SMS credits remaining, contact Selcom to recharge.")
    success = false
  elsif result.match(/Insufficient account balance/)
    log_error(result + " Contact Selcom to recharge.")
    success = false
  end
  puts result
  return success
end

def log_error(message)
  puts message
  $stderr.puts message
  @db.save_doc({:collection => "error", :source => $PROGRAM_NAME, :datetime => Time.now.strftime("%Y-%m-%d %H:%M:%S"), :message => message})
end

print "."

usersByDistrict = {}
@db.view('zanzibar/byCollection?key=' + CGI.escape('"user"'))['rows'].each do |user|
  user = user["value"]
  usersByDistrict[user["district"]] = [] unless usersByDistrict[user["district"]]
  usersByDistrict[user["district"]].push(user) unless user["inactive"] and user["inactive"] == true
end


@db.view("zanzibar/resultsAndNotificationsNotReceivedByTargetUser?include_docs=true")['rows'].each do |resultOrNotification|
  puts resultOrNotification

#puts "Executing view: zanzibar/rawNotificationsSMSNotSent?include_docs=true"
@db.view("zanzibar/rawNotificationsSMSNotSent?include_docs=true")['rows'].each do |notification|
  notification = notification["doc"]

  facility_district = notification["facility_district"]

  #BUG where I didn't capture facility_district properly
  if facility_district.nil? or facility_district == ["DISTRICT"]
    facility_district = districtByFacility(notification["hf"])
  end

  users = usersByDistrict[facility_district] unless facility_district.nil?

  # Switched from English to Swahili district names
  if users.nil?
    district_language_mapping = JSON.parse(RestClient.get "#{@db}/district_language_mapping", {:accept => :json})
    translated_district = district_language_mapping["english_to_swahili"][facility_district]
    users = usersByDistrict[translated_district] unless translated_district.nil?
  end

  if facility_district.nil?
    log_error("Can not find district for health facility: #{notification["hf"]} for notification: #{notification.inspect}")
  elsif users.nil?
    log_error("Can not find user for district: #{facility_district} for notification: #{notification.inspect}")
  else
    users.each do |user| 
      if send_message(user,"Case at #{notification["hf"]} with ID: #{notification["caseid"]} name: #{notification["name"]}. Accept/reject on tablet.")
        notification['SMSSent'] = true
        puts "Saving notification with SMSSent = true : #{notification.inspect}"
        puts @db.save_doc(notification)
      else
        puts "Notification not sent so not marking SMSSent as true"
      end
    end
  end
end
