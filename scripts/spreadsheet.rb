set :enviroment, :development

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



