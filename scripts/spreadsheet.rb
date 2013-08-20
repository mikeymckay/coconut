set :enviroment, :development

get '/spreadsheet/:start_time/:end_time' do |start_time, end_time|
  @db = CouchRest.database("http://localhost:5984/zanzibar")

  data = {}
  puts start_time
  puts end_time

  puts "Retrieving clients with visit date between #{start_time} and #{end_time}"
  keys = @db.view('coconut/clientsByVisitDate', {
# Note that start/end are backwards
    :startkey => end_time,
    :endkey => start_time,
    :descending => true,
    :include_docs => false
  })['rows'].map{|client| client["value"]}.sort.uniq

  puts "Retrieving client data for #{keys.length} cases"
  @db.view('coconut/clients', {
    :keys => keys,
    :include_docs => true
  })['rows'].each do |client_results|
    client_results = client_results["doc"]

    if client_results["ClientID"].nil?
      client_results["ClientID"] = client_results["IDLabel"]

    if client_results["question"].nil?
      client_results["question"] = client_results["source"]

    question = client_results['question']
    if data[question].nil?
      data[question] = {}
      data[question][client_results["ClientID"]] = []
    end
    data[question][client_results["ClientID"]].push client_results
  end

# Determine all possible fields
  fields = {}
  data.keys.each do |question|
    fields[question] = {}
    data[question].each do |result|
      result.keys.each do |field_name| 
        fields[question][field_name] = true
      end
    end
  end

  xls_filename = "coconut-#{start_time}---#{end_time}.xlsx".gsub(/ /,'--')

  Axlsx::Package.new do |spreadsheet|
    fields.keys.each do |question|
      sortedFields = fields[question].keys.sort
      spreadsheet.workbook.add_worksheet(:name => question) do |sheet|
        # Add spreadsheet header
        sheet.add_row(sortedFields)

        data[question].each do |result|
          row =  sortedFields.map{|field| 
            result[field] || ""
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
