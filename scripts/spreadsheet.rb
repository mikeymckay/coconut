set :enviroment, :development

get '/spreadsheet/:start_time/:end_time' do |start_time, end_time|
  @db = CouchRest.database("http://localhost:5984/coconut")

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
    end

    if client_results["question"].nil?
      client_results["question"] = client_results["source"]
    end

    question = client_results['question']
    if data[question].nil?
      data[question] = {}
    end
    if data[question][client_results["ClientID"]].nil?
      data[question][client_results["ClientID"]] = []
    end

    data[question][client_results["ClientID"]].push client_results
  end

puts "Determine all possible fields"
# Determine all possible fields
  fields = {}
  data.keys.each do |question|
    fields[question] = {}
    data[question].each do |client,results|
      results.each do |result| 
        result.each do |field_name,value| 
          fields[question][field_name] = true
        end
      end
    end
  end

  puts "Build spreadsheet"
  files = []
  fields.keys.each do |question|
    csv_filename = "coconut-#{question}-#{start_time}---#{end_time}.csv".gsub(/ /,'--')
    files.push csv_filename
    CSV.open(csv_filename,"wb") do csv
      sortedFields = fields[question].keys.sort
        csv << sortedFields
        data[question].each do |client,results|
          results.each do |result|
            row =  sortedFields.map{|field| 
              result[field] || ""
            }
            csv << row
          end
        end
      end
    end
  end
  filename = "coconut-#{start_time}---#{end_time}.zip".gsub(/ /,'--')
  `rm -f #{filename}`
  `zip #{filename} #{files.join(" ")}`
  send_file file, :filename => filename

# XLSX approach uses lots of resources
#  Axlsx::Package.new do |spreadsheet|
#    fields.keys.each do |question|
#      sortedFields = fields[question].keys.sort
#      spreadsheet.workbook.add_worksheet(:name => question) do |sheet|
#        # Add spreadsheet header
#        sheet.add_row(sortedFields)
#
#        data[question].each do |client,results|
#          results.each do |result|
#            row =  sortedFields.map{|field| 
#              result[field] || ""
#            }
#            sheet.add_row(row)
#          end
#        end
#      end
#    end
#    file = Tempfile.new("spreadsheet")
#    spreadsheet.serialize(file.path)
#    send_file file, :filename => xls_filename
#    file.unlink


end
