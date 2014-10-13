
get '/update_spreadsheet_header' do
  @db = CouchRest.database("http://localhost:5984/zanzibar")

  data = {}

  @db.view('zanzibar/cases', {
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
        # If duplicates, prefer the ones marked complete
        next if data[question][malaria_case_results["MalariaCaseID"]["complete"]] == "true" and malaria_case_results["complete"] != "true"
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

  # Sort them into an array
  data.keys.each do |question|
    fields[question] = fields[question].keys.sort
  end


  puts "Found #{fields.length} fields, uploading to spreadsheet_header in the couchdb"

  spreadsheet_header_doc = {}
  begin
    spreadsheet_header_doc = @db.get('spreadsheet_header')
  rescue
    puts "spreadsheet_header doesn't exist yet"
  end

  spreadsheet_header_doc["_id"] = "spreadsheet_header"
  spreadsheet_header_doc["last_updated"] = Time.now.to_s
  spreadsheet_header_doc["fields"] = fields

  @db.save_doc spreadsheet_header_doc


  return spreadsheet_header_doc.to_json

end


get '/spreadsheet_cleaned/:start_date/:end_date' do |start_date, end_date|
  output = `/usr/bin/ruby /home/crazy/coconut/scripts/downloadSpreadsheet.rb --start-date #{start_date} --end-date #{end_date}`
  path = output.lines.entries.last.chomp
  sleep 2
  puts `ls -altr /tmp`
  file = File.new path
  send_file file, :filename => "coconut-#{start_date}-#{end_date}.zip"
  file.close
end

# Shouldn't really use this one anymore
get '/spreadsheet/:start_time/:end_time' do |start_time, end_time|
  @db = CouchRest.database("http://localhost:5984/zanzibar")

  fields = @db.get('spreadsheet_header')["fields"]

  @identifyingAttributes = ["Name", "name", "FirstName", "MiddleName", "LastName", "ContactMobilepatientrelative", "HeadofHouseholdName", "ShehaMjumbe"];

  xls_filename = "coconut-surveillance-#{start_time}---#{end_time}.xlsx".gsub(/ /,'--')

  Axlsx::Package.new do |spreadsheet|
    fields.keys.each do |question|
      question_fields = fields[question]
      spreadsheet.workbook.add_worksheet(:name => question) do |sheet|
        # Add spreadsheet header
        sheet.add_row(fields[question])

        @db.view('zanzibar-server/resultsAsSpreadsheetRow', {
# Note that start/end are backwards
          :startkey => [question,end_time],
          :endkey => [question,start_time],
          :descending => true,
          :include_docs => false
        })['rows'].each do |row|
          row = row["value"]

          row = fields[question].each_with_index.map{|field,index| 
            if @identifyingAttributes.include?(field) and row[index]
              Digest::SHA1.base64digest(row[index])
            else
              row[index] || ""
            end
          }
          sheet.add_row(row)

        end
      end
    end
    file = Tempfile.new("spreadsheet")
    spreadsheet.serialize(file.path)
    send_file file, :filename => xls_filename
    file.unlink

  end

end
