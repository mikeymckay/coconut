require 'rubygems'
require 'couchrest'
require 'cgi'
require 'json'
require 'net/http'

passwords = JSON.parse(IO.read("passwords.json"))

@db = CouchRest.database("http://mikeymckay.iriscouch.com:5984/zanzibar")

#@facilityHierarchyJSON = '{"CHAKECHAKE":["CHONGA","DIRA","GOMBANI","MGELEMA","MVUMONI","NDAGONI","PUJINI","SHUNGI","TUNDAUA","UWANDANI","ZIWANI"],"MICHEWENI":["FINYA","KINYASINI","KIUYU KIPANGANI","KIUYU MBUYUNI","KONDE","MAKANGALE","MAZIWA NGOMBE","MKIAWANGOMBE","MSUKA","SHUMBA VIAMBONI","SIZINI","TUMBE","WINGWI"],"MKOANI":["BOGOA","CHAMBANI","KANGANI","KENGEJA","KISIWA PANZA","KIWANI","MAKOMBENI","MAKOONGWE","MTAMBILE","MTANGANI","MWAMBE","SHAMIANI","SHIDI","UKUTINI","WAMBAA"],"WETE":["CHWALE","FUNDO","JADIDA","JUNGUNI","KAMBINI ","KANGAGANI","KISIWANI","KIUNGONI","KIUYU MINUNGWINI","KOJANI","MTAMBWE","MZAMBARAUNI","OLE","PANDANI","TUNGAMAA","UKUNJWI","UONDWE","VUMBA"],"CENTRAL":["BAMBI","CHARAWE","CHEJU","CHWAKA","DUNGA","JENDELE","KIBOJE","MACHUI","MARUMBI","MCHANGANI","MICHAMVI","MIWANI","MWERA","NDIJANI BANIANI","NDIJANI MSEWENI","PONGWE","TUNGUU","UKONGORONI","UMBUJI","UNGUJA UKUU","UROA","UZI","UZINI"],"NORTH A":["CHAANI KUBWA","GAMBA","KIDOTI","KIJINI","MASINGINI","MATEMWE","MKOKOTONI","NUNGWI","PWANI MCHANGANI","TAZARI","TUMBATU GOMANI","TUMBATU JONGOWE"],"NORTH B":["BUMBWINI","BUMBWINI MAKOBA","DONGE MCHANGANI","DONGE VIJIBWENI","FUJONI","KITOPE","KIWENGWA","MAHONDA","UPENJA","ZINGWEZINGWE"],"SOUTH":["BWEJUU","JAMBIANI","KIBUTENI","KITOGANI","KIZIMKAZI DIMBANI","KIZIMKAZI MKUNGUNI","MTENDE","MUYUNI","PAJE"],"URBAN":["ALI AMOUR","BANDARINI","CHUMBUNI","JANGOMBE MPENDAE","JKU SAATENI","KIDONGO CHEKUNDU","KIDUTANI","MAFUNZO","MATARUMBETA","MKELE","RAHA LEO","SDA MEYA","SEBLENI","SHAURIMOYO","ZIWANI POLICE"],"WEST":["Al-HIJRA","BEIT-EL-RAAS","BWEFUM","CHUKWANI","FUONI","FUONI KIBONDENI","KIEMBE SAMAKI","KISAUNI","KIZIMBANI","KMKM KAMA","KOMBENI","MAGOGONI","MATREKTA","SANASA","SELEM","SHAKANI","AL-HIJRI","WELEZO"]}'


  @facilityHierarchyJSON = '{
    "CHAKECHAKE": ["CHONGA", "DIRA", "GOMBANI", "MGELEMA", "MVUMONI", "NDAGONI", "PUJINI", "SHUNGI", "TUNDAUA", "UWANDANI", "ZIWANI", "CHAKECHAKE", "VITONGOJI"],
    "MICHEWENI": ["FINYA", "KINYASINI", "KIUYU KIPANGANI", "KIUYU MBUYUNI", "KONDE", "MAKANGALE", "MAZIWA NGOMBE", "MKIAWANGOMBE", "MSUKA", "SHUMBA VIAMBONI", "SIZINI", "TUMBE", "WINGWI", "MICHEWENI"],
    "MKOANI": ["BOGOA", "CHAMBANI", "KANGANI", "KENGEJA", "KISIWA PANZA", "KIWANI", "MAKOMBENI", "MAKOONGWE", "MTAMBILE", "MTANGANI", "MWAMBE", "SHAMIANI", "SHIDI", "UKUTINI", "WAMBAA", "ABDALA MZEE"],
    "WETE": ["CHWALE", "FUNDO", "JADIDA", "JUNGUNI", "KAMBINI ", "KANGAGANI", "KISIWANI", "KIUNGONI", "KIUYU MINUNGWINI", "KOJANI", "MTAMBWE", "MZAMBARAUNI", "OLE", "PANDANI", "TUNGAMAA", "UKUNJWI", "UONDWE",    "VUMBA", "WETE"],
    "CENTRAL": ["BAMBI", "CHARAWE", "CHEJU", "CHWAKA", "DUNGA", "JENDELE", "KIBOJE", "MACHUI", "MARUMBI", "MCHANGANI", "MICHAMVI", "MIWANI", "MWERA", "NDIJANI BANIANI", "NDIJANI MSEWENI", "PONGWE", "TUNGUU",     "UKONGORONI", "UMBUJI", "UNGUJA UKUU", "UROA", "UZI", "UZINI"],
    "NORTH A": ["CHAANI KUBWA", "GAMBA", "KIDOTI", "KIJINI", "MASINGINI", "MATEMWE", "MKOKOTONI", "NUNGWI", "PWANI MCHANGANI", "TAZARI", "TUMBATU GOMANI", "TUMBATU JONGOWE", "KIVUNGE"],
    "NORTH B": ["BUMBWINI", "BUMBWINI MAKOBA", "DONGE MCHANGANI", "DONGE VIJIBWENI", "FUJONI", "KITOPE", "KIWENGWA", "MAHONDA", "UPENJA", "ZINGWEZINGWE"],
    "SOUTH": ["BWEJUU", "JAMBIANI", "KIBUTENI", "KITOGANI", "KIZIMKAZI DIMBANI", "KIZIMKAZI MKUNGUNI", "MTENDE", "MUYUNI", "PAJE", "MAKUNDUCHI"],
    "URBAN": ["ALI AMOUR", "BANDARINI", "CHUMBUNI", "JANGOMBE MPENDAE", "JKU SAATENI", "KIDONGO CHEKUNDU", "KIDUTANI", "MAFUNZO", "MATARUMBETA", "MKELE", "RAHA LEO", "SDA MEYA", "SEBLENI", "SHAURIMOYO", "ZIWANI  POLICE", "MNAZI MMOJA"],
    "WEST": ["Al-HIJRA", "BEIT-EL-RAAS", "BWEFUM", "CHUKWANI", "FUONI", "FUONI KIBONDENI", "KIEMBE SAMAKI", "KISAUNI", "KIZIMBANI", "KMKM KAMA", "KOMBENI", "MAGOGONI", "MATREKTA", "SANASA", "SELEM", "SHAKANI",   "AL-HIJRI", "WELEZO"]
  }'


def districtByFacility(facility)
  facilityHierarchy = JSON.parse(@facilityHierarchyJSON)
  facilityHierarchy.each do |district,facilityList|
    if facilityList.include?(facility) then
      return district
    end
  end
  return nil
end

def send_message(user,message)
  success = true
  phone_number = user["_id"].sub(/user\./,"").sub(/^0/,"255")
  message = CGI.escape(message)
  puts "Send '#{message}' message to #{phone_number} at #{Time.now}" 
  result = `curl -s -S -k -X GET "https://paypoint.selcommobile.com/bulksms/dispatch.php?msisdn=#{phone_number}&user=#{passwords["username3"]}&password=#{["password3"]}&message=#{message}"`
  if result.match(/.*:.*:(.*)/) and Integer($1) < 20
    log_error("Only #{$1} SMS credits remaining, contact Selcom to recharge.")
    success = false
  elsif result.match(/Insufficient account balance/)
    log_error(result + " Contact Selcom to recharge.")
    success = false
  end
  puts result
  return success
end

def log_error(message)
  puts message
  $stderr.puts message
  @db.save_doc({:collection => "error", :source => $PROGRAM_NAME, :date => "#{`date`}", :message => message})
end

print "."

usersByDistrict = {}
@db.view('zanzibar/byCollection?key=' + CGI.escape('"user"'))['rows'].each do |user|
  user = user["value"]
  usersByDistrict[user["district"]] = [] unless usersByDistrict[user["district"]]
  usersByDistrict[user["district"]].push(user)
end

#puts "Executing view: zanzibar/rawNotificationsSMSNotSent?include_docs=true"
@db.view("zanzibar/rawNotificationsSMSNotSent?include_docs=true")['rows'].each do |notification|
  notification = notification["doc"]

  district = districtByFacility(notification["hf"])
  users = usersByDistrict[district] unless district.nil?

  if district.nil?
    log_error("Can not find district for health facility: #{notification["hf"]} for notification: #{notification.inspect}")
  elsif users.nil?
    log_error("Can not find user for district: #{district} for notification: #{notification.inspect}")
  else
    users.each do |user| 
      if send_message(user,"New case at facility #{notification["hf"]} for case ID: #{notification["caseid"]} name: #{notification["name"]}. 'Get Data' on tablet and proceed to #{notification["hf"]}")
        notification['SMSSent'] = true
        puts "Saving notification with SMSSent = true : #{notification.inspect}"
        puts @db.save_doc(notification)
      else
        puts "Notification not sent so not marking SMSSent as true"
      end
    end
  end
end
