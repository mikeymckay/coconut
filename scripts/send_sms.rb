require 'cgi'
require 'json'

path = File.dirname(__FILE__)
@passwords = JSON.parse(IO.read("#{path}/passwords.json")) 

def send_sms(phone_number,message)
  send_selcom(phone_number,message)
end

def send_selcom(phone_number,message)
  success = true
  phone_number = phone_number.sub(/^\+/,"").sub(/^0/,"255")
  message = CGI.escape(message)
  puts "#{Time.now} - Send #{phone_number}: #{message}."
  result = `curl -s -S -k -X GET "https://paypoint.selcommobile.com/bulksms/dispatch.php?msisdn=#{phone_number}&user=#{@passwords["username3"]}&password=#{@passwords["password3"]}&message=#{message}"`
  if result.match(/.*:.*:(.*)/) and Integer($1) < 20
    STDERR.puts result
    log_error("Only #{$1} SMS credits remaining, contact Selcom to recharge.")
    success = false
  elsif result.match(/Insufficient account balance/)
    STDERR.puts result
    log_error(result + " Contact Selcom to recharge.")
    success = false
  end
  puts result
  return success
end

def send_bongo_live(to,message)

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

