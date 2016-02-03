require 'rubygems'
require 'couchrest'
require 'cgi'
require 'json'
require 'time'
require 'yaml'

@passwords = JSON.parse(IO.read("passwords.json"))

@db = CouchRest.database("http://localhost:5984/zanzibar")
@facilityHierarchy = JSON.parse(RestClient.get "#{@db}/Facility%20Hierarchy", {:accept => :json})["hierarchy"]

def districtByFacility(facility)
  @facilityHierarchy.each do |district,facilityData|
    if facilityData.map{|data| data["facility"]}.include?(facility) then
      return district
    end
  end
  return nil
end

def send_message_to_number(to,message)

  unless to[0] == "0" or to[0] == "+"
    to = "+" + to
  end
  puts "#{Time.now} - Send #{to}: #{message}."
  result = RestClient.get "http://www.bongolive.co.tz/api/sendSMS.php", {
    :params  => {
      :destnum    => to,
      :message    => message
    }.merge(@passwords["bongo_credentials"])
  }
  puts result
  result
end

def send_message(user,message)
  phone_number = user["_id"].sub(/user\./,"").sub(/^0/,"255")
  return send_message_to_number(phone_number, message)
end

def log_error(message)
  puts message
  $stderr.puts message
  @db.save_doc({:collection => "error", :source => $PROGRAM_NAME, :datetime => Time.now.strftime("%Y-%m-%d %H:%M:%S"), :message => message})
end

$english_to_swahili = JSON.parse(RestClient.get "#{@db}/district_language_mapping", {:accept => :json})["english_to_swahili"]
$swahili_to_english = $english_to_swahili.invert

def get_district_names(district)
  return [($swahili_to_english[district] or district), ($english_to_swahili[district] or district)].uniq
end

print "."

usersByDistrict = {}
@db.view('zanzibar/byCollection?key=' + CGI.escape('"user"'))['rows'].each do |user|
  user = user["value"]

  if user["district"]
    get_district_names(user["district"]).each do |name|
      usersByDistrict[name] = [] unless usersByDistrict[name]
      usersByDistrict[name].push(user) unless user["inactive"] and (user["inactive"] == true or user["inactive"] == 'true')
    end
  end
  
end

transferred_cases = []
@db.view("zanzibar/resultsAndNotificationsNotReceivedByTargetUser?include_docs=true")['rows'].each do |resultOrNotification|
  caseId = resultOrNotification["value"][1]
  next if transferred_cases.include? caseId
  doc = resultOrNotification["doc"]

  last_time_transfer_SMS_was_sent = doc["transferred"].last["notifiedViaSms"].last
  if last_time_transfer_SMS_was_sent 
    seconds_since_sent = (Time.now - Time.parse(last_time_transfer_SMS_was_sent))
    # Remind once a day
    next if seconds_since_sent < 60 * 60 * 24
  end

  next if doc["transferred"].last["notifiedViaSms"].length > 20 # Only try sending 20 for 20 days

  to_phone_number = resultOrNotification["key"].gsub(/user\./,"").sub(/^0/,"255")
  from_user = @db.get(resultOrNotification["value"][0])
  from_user_string = "#{from_user["district"]} #{from_user["name"]} #{from_user["_id"].gsub(/user\./,"")}"

  if send_message_to_number(to_phone_number,"#{caseId} transferred to you from #{from_user_string}. Accept/reject on tablet.")
    doc["transferred"].last["notifiedViaSms"].push Time.now.to_s
    @db.save_doc(doc)
  end
end

#puts "Executing view: zanzibar/rawNotificationsSMSNotSent?include_docs=true"
@db.view("zanzibar/rawNotificationsSMSNotSent?include_docs=true")['rows'].each do |notification|
  notification = notification["doc"]

  facility_district = notification["facility_district"]

  #BUG where I didn't capture facility_district properly
  if facility_district.nil? or facility_district == ["DISTRICT"]
    facility_district = districtByFacility(notification["hf"])
  end

  users = usersByDistrict[facility_district] unless facility_district.nil?

  if facility_district.nil?
    log_error("Can not find district for health facility: #{notification["hf"]} for notification: #{notification.inspect}")
  elsif users.nil?
    log_error("Can not find user for district: #{facility_district} for notification: #{notification.inspect}")
  else
    users.each do |user| 
      if send_message(user,"Case at #{notification["hf"]} with ID: #{notification["caseid"]} name: #{notification["name"]}. Accept/reject on tablet.")
        notification['SMSSent'] = true
        notification['numbersSentTo'] = [] unless notification['numbersSentTo']
        notification['numbersSentTo'].push(user["_id"])
        puts "Saving notification with SMSSent = true : #{notification.inspect}"
        puts @db.save_doc(notification)
      else
        puts "Notification not sent so not marking SMSSent as true"
      end
    end
  end
end
