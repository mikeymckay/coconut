
get '/facility_mobile_number/:number' do |number|
  return facility_data(number).to_json
end

post '/get_facility_data' do
  return facility_data(params["phone"]).to_json
end

post '/valid_facility/:question' do |question|
  facility = facility_data(params["phone"])
  facility_name = facility["facility"].upcase
  facility_district = facility["facility_district"].upcase
  if facility_name
    return {
      "facility" => facility_name,
      "district" => facility_district,
      "status" => "Valid",
      "message" => "Hi #{facility_name}, #{question}?"
    }.to_json
  else
    return {
      "status" => "Invalid",
      "message" => "Sorry, we don't have a health facility registered for #{params["phone"]}."
    }.to_json
  end
end

post '/valid_date_today_or_earlier' do
  date_match = params["text"].match(/^(\d{1,2})[ \.-](\d{1,2})[ \.-](\d{4})$/)

  if date_match
    (day,month,year) = date_match.captures
    errors = error_messages_for_date_today_or_earlier(day,month,year)
  else
    errors = "Not a valid date: #{params["text"]}, send as day-month-year e.g. 25-12-2014"
  end

  if errors.nil?
    month_string = "JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC".split(/,/)[month.to_i-1]
    {
      "valid_date_status" => "valid",
      "valid_date_message" => "#{day}-#{month_string}-#{year}",
      "date" => "#{year}-#{month}-#{day}"
    }
  else
   {
      "valid_date_status" => "invalid",
      "invalid_date_message" => errors
    }
  end.to_json
end


post '/new_case' do
  @db = CouchRest.database("http://localhost:5984/zanzibar")

  values = JSON.parse(params[:values])

  shehia = params[:text].upcase

  if valid_shehia? shehia
    facility_data = facility_data(params["phone"])

    (day,month,year) =  get_result(values,"Test Date").match(/^(\d{1,2})[ \.-](\d{1,2})[ \.-](\d{4})$/).captures

    result = save_new_case(params["phone"],facility_data["facility"], facility_data["facility_district"], get_result(values,"Name"), day, month, year, shehia)

    return {
      "status" => "valid",
      "new_case_message" => result
    }.to_json
  else
    return {
      "closest_match" => FuzzyMatch.new(shehia_list()).find(shehia),
      "shehia" => shehia,
      "status" => "invalid"
    }.to_json

  end
end

post '/weekly_report/year_week' do
  match = params["text"].match(/(\d+) +(\d+)/)

  unless match
    return {"status" => "Invalid", "year_week_message" => "Wrong format. Please send the year and week for the report. (e.g. 2014 25)"}.to_json
  end

  (year,week) = match.captures
  
  year_week_error = weekly_report_year_week_error(year,week)

  if year_week_error
    {"year_week_status" => "Invalid", "year_week_message" => "#{year_week_error} Please send year and week (e.g. 2014 25)"}.to_json
  else
    {"year_week_status" => "Valid", "year" => year, "week" => week}.to_json
  end

end

post '/weekly_report/under_5' do
  validate_opd(params["text"], "under_5")
end

post '/weekly_report/over_5' do
  validate_opd(params["text"], "over_5")
end

post '/facility/:facility/district/:district/year/:year/week/:week/u5_total/:under_5_total/u5_mp/:under_5_malaria_positive/u5_mn/:under_5_malaria_negative/o5_total/:over_5_total/o5_mp/:over_5_malaria_positive/o5_mn/:over_5_malaria_negative' do |facility, district, year, week, under_5_total, under_5_malaria_positive, under_5_malaria_negative, over_5_total, over_5_malaria_positive, over_5_malaria_negative|

  result = save_weekly_report(params["phone"],facility, district, year, week, under_5_total, under_5_malaria_positive, under_5_malaria_negative, over_5_total, over_5_malaria_positive, over_5_malaria_negative)

  return {
    "status" => "valid",
    "success_message" => result
  }.to_json

end


get '/255686375965/incoming' do
  sent_from = params["org"]
  facility_data = facility_data(sent_from)

  if facility_data["facility"].nil? or facility_data["facility_district"].nil?
    return send_message(sent_from,"No health facility found for your mobile number. Contact +255 7888 074 705 to add your number to a facility.")
  end

  if params["message"].match(/^shortcut/i)
    weekly_shortcut = "weekly shortcut: 'weekly year week under_5_total under_5_malaria_pos under_5_mal_neg over_5_total over_5_mal_pos over_5_mal_neg' e.g. 2013 21 31 1 21 44 1 1"
    case_shortcut = "case shortcut: 'name positive_test_date shehia' e.g. Kareem Abdul 25-12-2014 kitope"
    send_message(sent_from,weekly_shortcut)
    send_message(sent_from,case_shortcut)
  end

  weekly_match = params["message"].match(/^weekly (\d\d\d\d) (\d{1,2}) (\d{1,3}) (\d{1,3}) (\d{1,3}) (\d{1,3}) (\d{1,3}) (\d{1,3})$/i)
  case_match = params["message"].match(/^case (.{2,}) (\d\d)-(\d\d)-(\d\d\d\d) (.+)$/i)

  if weekly_match
    errors = check_for_errors_weekly_shortcut(*weekly_match.captures)
    if errors.empty?
      result = save_weekly_report(sent_from, facility_data["facility"], facility_data["facility_district"], *weekly_match.captures)
      puts result
      send_message(sent_from,result)
    else
      send_message(sent_from,"Errors: #{errors.join(", ")}. Starting normal weekly data entry")
      forward_to_textit(params["org"],params["message"])
    end
  elsif case_match
    errors = check_for_errors_case_shortcut(*case_match.captures)
    if errors.empty?
      result = save_new_case(sent_from, facility_data["facility"], facility_data["facility_district"], *case_match.captures  )
      send_message(sent_from,result)
    else
      send_message(sent_from,"Errors: #{errors.join(", ")}. Starting normal case data entry")
      forward_to_textit(params["org"],params["message"])
    end
  else
    # Default to just passing message to textit
    forward_to_textit(params["org"],params["message"])
  end

end