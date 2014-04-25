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
  db = CouchRest.database("http://localhost:5984/zanzibar")

  facility_district = nil
  facility = nil

  facilityHierarchy = JSON.parse(RestClient.get "#{db}/Facility%20Hierarchy", {:accept => :json})["hierarchy"]
  facilityHierarchy.each do |district,facilityData|
    break if facility_district and facility
    facilityData.each do |data|
      if data["mobile_numbers"].include? number
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

get '/facility_mobile_number/:number' do |number|
  return facility_data(number).to_json
end

post '/get_facility_data' do
  return facility_data(params["phone"]).to_json
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

def get_result(values, param_name)
  values.map{|value| value["text"] if value["label"] == param_name}.compact.last
end

post '/new_case' do
  db = CouchRest.database("http://localhost:5984/zanzibar")
  shehias = db.get("Geo Hierarchy")["hierarchy"].leaves.flatten

  values = JSON.parse(params[:values])

  shehia = params['text'].upcase

  if shehias.include? shehia
    facility_info = facility_data(params["phone"])

    # Milliseconds (not quite) since 2014,1,1 + 1 random digit base 30 encoded
    caseid = to_base((Time.now - Time.new(2014,1,1))*1000)

    doc = {
      "type" => "new_case",
      "source" => "textit",
      "source_phone" => params["phone"],
      "caseid" => caseid,
      "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "name" => get_result(values, "Name").upcase,
      "positive_test_date" => get_result(values, "Test Date"),
      "shehia" => shehia,
      "hf" => facility_info["facility"].upcase,
      "facility_district" => facility_info["facility_district"].upcase
    }

    return doc.merge( {
      "status" => "valid"
    }).to_json
  else
    return {
      "closest_match" => FuzzyMatch.new(shehias).find(shehia),
      "shehia" => shehia,
      "status" => "invalid"
    }.to_json

  end
end

post '/weekly_report/validate' do
  status = "valid"
  values = JSON.parse(params[:values])

  case params["step"]
    when "53858658-f832-4a07-b6f4-8baae2fcb8ea"
      status = "invalid" unless (2014 <= params['text'].to_i and params['text'].to_i <= Date.today.year)

    when "f302660f-7cc5-477e-aab7-f868bfcc1f01"
      year = get_result(values, "year")
      week = params['text']
      begin
        Date.strptime("#{year}-#{week}", '%Y-%W')
      rescue ArgumentError
        status = "invalid"
      end

    else
      puts "Unhandled step: #{params["step"]}"


  end

  return {"status" => status}.to_json


end

post '/weekly_report' do
  values = JSON.parse(params[:values])

  facility_info = facility_data(params["phone"])

  doc = {
    "type" => "weekly_report",
    "source" => "textit",
    "source_phone" => params["phone"],
    "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    "hf" => facility_info["facility"].upcase,
    "facility_district" => facility_info["facility_district"].upcase,
    "year" => get_result(values, "year"),
    "week" => get_result(values, "week"),
    "under 5 opd" => get_result(values, "Under 5 OPD"),
    "under 5 positive" => get_result(values, "Under 5 Positive"),
    "under 5 negative" => get_result(values, "Under 5 Negative"),
    "over 5 opd" => get_result(values, "Over 5 OPD"),
    "over 5 positive" => get_result(values, "Over 5 Positive"),
    #"over 5 negative" => get_result(values, "Over 5 Negative")
    "over 5 negative" => params['text'].upcase
  }

  return doc.merge( {
    "status" => "valid"
  } ).to_json
end


get '/spreadsheet/:start_time/:end_time' do |start_time, end_time|
  @db = CouchRest.database("http://localhost:5984/zanzibar")
  @identifyingAttributes = ["Name", "name", "FirstName", "MiddleName", "LastName", "ContactMobilepatientrelative", "HeadofHouseholdName", "ShehaMjumbe"];

  data = {}
  puts start_time
  puts end_time

  puts "Retrieving case IDs"
  keys = @db.view('zanzibar/caseIDsByDate', {
# Note that start/end are backwards
    :startkey => end_time,
    :endkey => start_time,
    :descending => true,
    :include_docs => false
  })['rows'].map{|malaria_case| malaria_case["value"]}.sort.uniq

  puts "Retrieving case data for #{keys.length} cases"
  @db.view('zanzibar/cases', {
    :keys => keys,
    :include_docs => true
  })['rows'].each do |malaria_case_results|
    malaria_case_results = malaria_case_results["doc"]
    question = malaria_case_results['question']
    unless question.nil?
      if question == "Household Members"
        data[question] = [] if data[question].nil?
        data[question].push malaria_case_results
      else
        data[question] = {} if data[question].nil?
        data[question][malaria_case_results["MalariaCaseID"]] = malaria_case_results
      end
    end
    if malaria_case_results['question'].nil? and malaria_case_results['hf']
      question = 'USSD Notification'
      data[question] = {} if data[question].nil?
      data[question][malaria_case_results["caseid"]] = malaria_case_results
    end
  end

# Determine all possible fields
  fields = {}
  data.keys.each do |question|
    fields[question] = {}
    if question == "Household Members"
      data[question].each do |result|
        result.keys.each do |field_name| 
          fields[question][field_name] = true
        end
      end
    else
      data[question].each do |case_id,result|
        result.keys.each do |field_name| 
          fields[question][field_name] = true
        end
      end
    end
  end

  xls_filename = "coconut-surveillance-#{start_time}---#{end_time}.xlsx".gsub(/ /,'--')

  Axlsx::Package.new do |spreadsheet|
    fields.keys.each do |question|
      sortedFields = fields[question].keys.sort
#      csv_filename = "coconut-surveillance-#{question}--#{start_time}---#{end_time}.csv".gsub(/ /,'--')
#      CSV.open(csv_filename, "wb") do |csv|
        spreadsheet.workbook.add_worksheet(:name => question) do |sheet|
          # Add spreadsheet header
#          csv << sortedFields
          sheet.add_row(sortedFields)

          if question == "Household Members"
            data[question].each do |result|
              row =  sortedFields.map{|field| 
                if @identifyingAttributes.include?(field) and result[field]
                  Digest::SHA1.base64digest(result[field])
                else
                  result[field] || ""
                end
              }
#              csv << row
              sheet.add_row(row)
            end
          else
            data[question].each do |case_id,result|
              row =  sortedFields.map{|field| 
                if @identifyingAttributes.include?(field) and result[field]
                  Digest::SHA1.base64digest(result[field])
                else
                  result[field] || ""
                end
              }
#              csv << row
              sheet.add_row(row)
            end
          end


        end
#      end
#      puts "Created #{csv_filename}"
    end
    file = Tempfile.new("spreadsheet")
    spreadsheet.serialize(file.path)
    send_file file, :filename => xls_filename
    file.unlink

  end

end



