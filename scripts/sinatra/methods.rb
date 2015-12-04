#set :bind, '0.0.0.0'

set :enviroment, :development

class Hash
  # {'x'=>{'y'=>{'z'=>1,'a'=>2}}}.leaves == [1,2]
  def leaves
    leaves = []

    each_value do |value|
      value.is_a?(Hash) ? value.leaves.each{|l| leaves << l } : leaves << value
    end

    leaves
  end
end


def facility_data(number)
  @db = CouchRest.database("http://localhost:5984/zanzibar")
  # Get just the numbers, ignore leading zeroes
  number = number.gsub(/\D/, '').gsub(/^0/,"").gsub(/^+255/,"")

  facility_district = nil
  facility = nil

  facilityHierarchy = JSON.parse(RestClient.get "#{@db}/Facility%20Hierarchy", {:accept => :json})["hierarchy"]
  facilityHierarchy.each do |district,facilityData|
    break if facility_district and facility
    facilityData.each do |data|
      if data["mobile_numbers"].map{|number| number.gsub(/\D/,'').gsub(/^0/,"") }.include? number
        facility_district = district
        facility = data["facility"]
        break
      end
    end
  end

  return {
    "facility" => facility,
    "facility_district" => facility_district
  }
end


# Convert a number to a more compact and easy to transcribe string
def to_base(number,to_base = 30)
  # we are taking out the following letters B, I, O, Q, S, Z because the might be mistaken for 8, 1, 0, 0, 5, 2 respectively
  base_map = ["0","1","2","3","4","5","6","7","8","9","A","C","D","E","F","G","H","J","K","L","M","N","P","R","T","U","V","W","X","Y"]

  results = ''
  quotient = number.to_i

  while quotient > 0
    results = base_map[quotient % to_base] + results
    quotient = (quotient / to_base)
  end
  results
end

def new_case_id()
  # Milliseconds (not quite) since 2014,1,1 base 30 encoded
  caseid = to_base((Time.now - Time.new(2014,1,1))*1000)
end

def get_result(values, param_name)
  values.map{|value| value["text"] if value["label"] == param_name}.compact.last
end


def error_messages_for_date_today_or_earlier(day,month,year)
  error_message = nil

  begin
    date = Date.strptime("#{year}-#{month}-#{day}", '%Y-%m-%d')
    if date > Date.today
      return "#{day}-#{month}-#{year} is not valid, must be on or before today's date: #{Date.today().strftime("%d-%m-%Y")}."
    end
  rescue ArgumentError
    return "#{day}-#{month}-#{year} is not a valid date, send as day-month-year"
  end

  return error_message

end


def save_new_case(source_phone,facility,district,name,positive_test_day,positive_test_month,positive_test_year, shehia)
  positive_test_date_year_month_day = "#{positive_test_year}-#{positive_test_month}-#{positive_test_day}"
  positive_test_month_string = "JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC".split(/,/)[positive_test_month.to_i-1]
  positive_test_date_string_for_user = "#{positive_test_day}#{positive_test_month_string}#{positive_test_year}"

  caseid = new_case_id()

  doc = {
    "type" => "new_case",
    "source" => "textit",
    "source_phone" => source_phone,
    "caseid" => caseid,
    "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    "name" => name,
    "positive_test_date" => positive_test_date_year_month_day,
    "shehia" => shehia,
    "hf" => facility.upcase,
    "facility_district" => district.upcase
  }
  @db.save_doc(doc)

  return "Created #{caseid}: #{name} #{positive_test_date_string_for_user} from #{shehia} for #{facility} in #{district}"

end

def shehia_list
  @db.get("Geo Hierarchy")["hierarchy"].leaves.flatten
end

def valid_shehia?(shehia)
  shehia_list().include? shehia
end

def weekly_report_year_week_error(year,week)
  year = year.to_i
  week = week.to_i
  maximum_number_of_weeks_in_any_year = 52
  start_year = 2014

  if (year < start_year or year > Date.today.year)
    "#{year} is not a valid year, must be a number between 2014 and #{Date.today.year}."
  elsif (week > maximum_number_of_weeks_in_any_year)
    "Week, #{week}, must be less than #{maximum_number_of_weeks_in_any_year}."
  elsif (Date.commercial(year,week) > Date.today)
    "Year week, #{year} #{week}, must be the same or earlier than today's year and week: #{Date.today.year} #{Date.today.cweek}."
  else
    nil
  end

end

def validate_opd(text,prefix)
  (total_visits, malaria_positive, malaria_negative) = text.split(/ +/).map{|text_value| text_value.to_i}
  valid = true
  message = ""
  total_visits_limit = 1000

  if total_visits.nil? or malaria_positive.nil? or malaria_negative.nil?
    valid = false
    message = "At least three numbers are required."
  elsif total_visits > total_visits_limit
    valid = false
    message = "Total visits '#{total_visits}' is not valid, must be less than #{total_visits_limit}"

  elsif malaria_positive + malaria_negative > total_visits
    valid = false
    message = "The sum of malaria positive and malaria negative (#{malaria_positive}+#{malaria_negative} = #{malaria_positive+malaria_negative}) must not exceed the total visits (#{total_visits})."
  end

  if valid
    {
      "#{prefix}_status" => "Valid", 
      "#{prefix}_total_visits" => total_visits, 
      "#{prefix}_malaria_positive" => malaria_positive, 
      "#{prefix}_malaria_negative" => malaria_negative 
    }.to_json
  else
    {
      "#{prefix}_status" => "Invalid", 
      "#{prefix}_message" => message + " Send #{prefix} 'total positive negative' again."
    }.to_json
  end

end


def save_weekly_report(source_phone,facility, district, year, week, under_5_total, under_5_malaria_positive, under_5_malaria_negative, over_5_total, over_5_malaria_positive, over_5_malaria_negative)

  @db = CouchRest.database("http://localhost:5984/zanzibar")

  doc = {
    "type" => "weekly_report",
    "source" => "textit",
    "source_phone" => source_phone,
    "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    "year" => year,
    "week" => week,
    "under 5 opd" => under_5_total,
    "under 5 positive" => under_5_malaria_positive,
    "under 5 negative" => under_5_malaria_negative,
    "over 5 opd" => over_5_total,
    "over 5 positive" => over_5_malaria_positive,
    "over 5 negative" => over_5_malaria_negative,
    "hf" => facility.upcase,
    "facility_district" => district.upcase
  }
  @db.save_doc(doc)

  return "Thanks. #{facility}, y#{year}, w#{week}: <5: [#{under_5_total}, +#{under_5_malaria_positive}, -#{under_5_malaria_negative} ] >5: [#{over_5_total} , +#{over_5_malaria_positive}, -#{over_5_malaria_negative}]"

end

def send_message(to,message)
  RestClient.get "http://www.bongolive.co.tz/api/sendSMS.php", {
    :params  => {
      :destnum    => to,
      :message    => message
    }.merge($passwords_and_config["bongo_credentials"])
  }
end

def check_for_errors_weekly_shortcut(year, week, under_5_total, under_5_positive, under_5_negative, over_5_total, over_5_positive, over_5_negative)

  errors = []

  year_week_error = weekly_report_year_week_error(year,week)
  errors.push year_week_error unless year_week_error.nil?

  valid_under_5_opd = validate_opd("#{under_5_total} #{under_5_positive} #{under_5_negative}","under_5")
  errors.push "under_5 data: #{valid_under_5_opd["under_5_message"]}" if valid_under_5_opd["under_5_status"] == "Invalid"
  valid_over_5_opd = validate_opd("#{over_5_total} #{over_5_positive} #{over_5_negative}", "over_5")
  errors.push "over_5 data: #{valid_over_5_opd["over_5_message"]}" if valid_over_5_opd["over_5_status"] == "Invalid"
  return errors
end

def check_for_errors_case_shortcut(name, day, month, year, shehia)
  errors = []
  error_messages_for_date_today_or_earlier =  error_messages_for_date_today_or_earlier(day,month,year)
  errors.push error_messages_for_date_today_or_earlier unless error_messages_for_date_today_or_earlier.nil?
  errors.push "Invalid shehia" unless valid_shehia? shehia
  return errors
end

def forward_to_textit(from,text)
  RestClient.post $passwords_and_config["textit"]["url_received"], {:from => from, :text => text}
end
