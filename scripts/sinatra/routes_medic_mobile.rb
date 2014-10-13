post '/new_medic_mobile_case' do
  @db = CouchRest.database("http://localhost:5984/zanzibar")
  shehias = @db.get("Geo Hierarchy")["hierarchy"].leaves.flatten

  facility = facility_data(params["phone"])
  facility_name = facility["facility"].upcase
  facility_district = facility["facility_district"].upcase
  if facility_name.nil?
    return {
      "status" => "invalid",
      "facility" => "invalid",
      "message" => "Sorry, we don't have a health facility registered for #{params["phone"]}."
    }.to_json
  end

  (version,form,data) = params["text"].split(/!/)
  if form.nil?
    return {
      "status" => "invalid",
      "message" => "Invalid message, please try again or report the problem."
    }.to_json
  elsif form == "RTIA"
    (name,level1_shehia,level2_shehia,level3_shehia,year,month,day) = data.split(/#+/)
    name.upcase!
    # All of these -1s are because Muvuku uses indexes that start at 1 instead of 0
    year = "2014,2015,2016,2017".split(/,/)[year.to_i-1]
    month = month.rjust(2,"0")
    day = day.rjust(2,"0")
    mappings = JSON.parse(IO.read("mappings.json"))
    shehia = mappings["level3"][level2_shehia.to_i-1][level3_shehia.to_i-1][1]["en"].upcase
    caseid = new_case_id()

    doc = {
      "type" => "new_case",
      "source" => "parallel sim",
      "source_phone" => params["phone"],
      "caseid" => caseid,
      "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "name" => name,
      "positive_test_date" => "#{year}-#{month}-#{day}",
      "shehia" => shehia,
      "hf" => facility_name,
      "facility_district" => facility_district
    }
    @db.save_doc(doc)

    return doc.merge( {
      "status" => "valid",
      "message" => "Asante, #{facility_name} reported #{name} from #{shehia} tested + on #{year}-#{month}-#{day}. Case: #{caseid}"
    }).to_json
  elsif form == "RTIB"
    (year,week,under_5_opd,under_5_positive,under_5_negative,over_5_opd,over_5_positive,over_5_negative) = data.split(/#+/)
    year = "2014,2015,2016,2017".split(/,/)[year.to_i-1]

    doc = {
      "type" => "weekly report",
      "source" => "parallel sim",
      "source_phone" => params["phone"],
      "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "year" => year,
      "week" => week,
      "under 5 opd" => under_5_opd,
      "under 5 positive" => under_5_positive,
      "under 5 negative" => under_5_negative,
      "over 5 opd" => over_5_opd,
      "over 5 positive" => over_5_positive,
      "over 5 negative" => over_5_negative,
      "hf" => facility_name,
      "facility_district" => facility_district
    }
    @db.save_doc(doc)

    return doc.merge({
      "status" => "valid",
      "message" => "Asante, #{facility_name} u sent: #{year},#{week} <5:#{under_5_opd} <5+:#{under_5_positive} <5-:#{under_5_negative} >5:#{over_5_opd} >5+:#{over_5_positive} >5-:#{over_5_negative}"
    }).to_json
    end

  return {
    "status" => "valid",
    "message" => "Thanks, #{facility_name} your data has been stored."
  }.to_json


end
