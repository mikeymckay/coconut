require 'rubygems'
require 'mechanize'
require 'couchrest'
require 'json'
require 'net/http'

passwords = JSON.parse(IO.read("passwords.json"))

print "."

columnNames = "
Year
Week
Submit Date
Zone
District
Facility
All OPD < 5
Mal POS < 5
Mal NEG < 5
Test Rate < 5
Pos Rate < 5
All OPD >= 5
Mal POS >= 5
Mal NEG >= 5
Test Rate >= 5
Pos Rate >= 5
".split("\n")

columnNames.shift()

data = {
}

#@db = CouchRest.database("http://coconutsurveillance:zanzibar@coconut.zmcp.org/zanzibar")
@db = CouchRest.database("http://coconutsurveillance:zanzibar@localhost:5984/zanzibar")

@agent = Mechanize.new
#@agent.user_agent_alias = "Mac Firefox"
loginForm = @agent.get('http://zmcp.selcommobile.com/index.php').form
loginForm.username = passwords["username1"]
loginForm.password = passwords["password1"]
@agent.submit(loginForm)

# Note the extra layer of authentication with a slightly different password
loginForm = @agent.get('http://zmcp.selcommobile.com/export.php').form
loginForm.access_login = passwords["username2"]
loginForm.access_password = passwords["password2"]
@agent.submit(loginForm)

# Get all of the data from meeds since 2013
# (Already got 2008-2013, assume it won't change)

#2013.upto(Time.now.year) do |year|
2014.upto(Time.now.year) do |year|
  print "#{year} "
  pageWithData = @agent.get("http://zmcp.selcommobile.com/export.php?submit_check=1&year=#{year}&week=0&year1=#{year}&week0=1&zone=0&district=0&facility=0&query=Query")

  pageWithData.search("//*[@id='bigRight']/table").search("tr").each do |row| 
    columnData = row.search("td").map{|td|td.text}
    if columnData.length != 17
      #puts columnData.length
      #puts "Skipping column data for: #{columnData.to_json}"
    else
#  puts columnData
      columnNames.each_with_index do |column, index|
          #puts columnData.to_yaml
          id = (columnData[0..1]+columnData[3..5]).join("-")

        if index == 0
          data[id] = {
            "_id" => id,
            "source" => "meedsWeekly.rb",
            "type" => "Weekly Facility Report"
          }
        end

        data[id][column] = columnData[index]
      end
    end
  end
end

couchdbData = {}
@db.view("zanzibar-server/weeklyDataBySubmitDate")['rows'].each do |row|
  couchdbData[row["key"]] = row["value"]
end

data.each do |id, dataset|
  if couchdbData[id] and couchdbData[id] == dataset["Submit Date"]
    #print "F"
    next
  # If it has been updated, then overwrite the data in couch with the new data
  elsif couchdbData[id] and couchdbData[id] != dataset["Submit Date"]
    puts "#{id} has been revised, saving new version"
    dataset["_rev"] = @db.get(id)["_rev"]
    @db.save_doc(dataset,true)
  else
    puts dataset
    print " #{id} "
    @db.save_doc(dataset,true)
  end
end

@db.bulk_save()

