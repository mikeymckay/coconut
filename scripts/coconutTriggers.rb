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
  @facilityHierarchy.each do |district,facilityList|
    if facilityList.include?(facility) then
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

#puts "Executing view: zanzibar/rawNotificationsSMSNotSent?include_docs=true"
@db.view("zanzibar/rawNotificationsSMSNotSent?include_docs=true")['rows'].each do |notification|
  notification = notification["doc"]

  district = districtByFacility(notification["hf"])
  users = usersByDistrict[district] unless district.nil?

  if district.nil?
    log_error("Can not find district for health facility: #{notification["hf"]} for notification: #{notification.inspect}")
  elsif users.nil?
    log_error("Can not find user for district: #{district} for notification: #{notification.inspect}")
  else
    users.each do |user| 
      if send_message(user,"Proceed to #{notification["hf"]} for case ID: #{notification["caseid"]} name: #{notification["name"]}")
        notification['SMSSent'] = true
        puts "Saving notification with SMSSent = true : #{notification.inspect}"
        puts @db.save_doc(notification)
      else
        puts "Notification not sent so not marking SMSSent as true"
      end
    end
  end
end
