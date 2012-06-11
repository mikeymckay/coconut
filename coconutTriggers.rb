require 'rubygems'
require 'couchrest'
require 'cgi'
require 'awesome_print'
require 'json'
require 'net/http'

@db = CouchRest.database("http://mikeymckay.iriscouch.com:5984/zanzibar")

@facilityHierarchyJSON = '{"CHAKECHAKE":["CHONGA","DIRA","GOMBANI","MGELEMA","MVUMONI","NDAGONI","PUJINI","SHUNGI","TUNDAUA","UWANDANI","ZIWANI"],"MICHEWENI":["FINYA","KINYASINI","KIUYU KIPANGANI","KIUYU MBUYUNI","KONDE","MAKANGALE","MAZIWA NGOMBE","MKIAWANGOMBE","MSUKA","SHUMBA VIAMBONI","SIZINI","TUMBE","WINGWI"],"MKOANI":["BOGOA","CHAMBANI","KANGANI","KENGEJA","KISIWA PANZA","KIWANI","MAKOMBENI","MAKOONGWE","MTAMBILE","MTANGANI","MWAMBE","SHAMIANI","SHIDI","UKUTINI","WAMBAA"],"WETE":["CHWALE","FUNDO","JADIDA","JUNGUNI","KAMBINI ","KANGAGANI","KISIWANI","KIUNGONI","KIUYU MINUNGWINI","KOJANI","MTAMBWE","MZAMBARAUNI","OLE","PANDANI","TUNGAMAA","UKUNJWI","UONDWE","VUMBA"],"CENTRAL":["BAMBI","CHARAWE","CHEJU","CHWAKA","DUNGA","JENDELE","KIBOJE","MACHUI","MARUMBI","MCHANGANI","MICHAMVI","MIWANI","MWERA","NDIJANI BANIANI","NDIJANI MSEWENI","PONGWE","TUNGUU","UKONGORONI","UMBUJI","UNGUJA UKUU","UROA","UZI","UZINI"],"NORTH A":["CHAANI KUBWA","GAMBA","KIDOTI","KIJINI","MASINGINI","MATEMWE","MKOKOTONI","NUNGWI","PWANI MCHANGANI","TAZARI","TUMBATU GOMANI","TUMBATU JONGOWE"],"NORTH B":["BUMBWINI","BUMBWINI MAKOBA","DONGE MCHANGANI","DONGE VIJIBWENI","FUJONI","KITOPE","KIWENGWA","MAHONDA","UPENJA","ZINGWEZINGWE"],"SOUTH":["BWEJUU","JAMBIANI","KIBUTENI","KITOGANI","KIZIMKAZI DIMBANI","KIZIMKAZI MKUNGUNI","MTENDE","MUYUNI","PAJE"],"URBAN":["ALI AMOUR","BANDARINI","CHUMBUNI","JANGOMBE MPENDAE","JKU SAATENI","KIDONGO CHEKUNDU","KIDUTANI","MAFUNZO","MATARUMBETA","MKELE","RAHA LEO","SDA MEYA","SEBLENI","SHAURIMOYO","ZIWANI POLICE"],"WEST":["Al-HIJRA","BEIT-EL-RAAS","BWEFUM","CHUKWANI","FUONI","FUONI KIBONDENI","KIEMBE SAMAKI","KISAUNI","KIZIMBANI","KMKM KAMA","KOMBENI","MAGOGONI","MATREKTA","SANASA","SELEM","SHAKANI","AL-HIJRI","WELEZO"]}'

def districtByFacility(facility)
  facilityHierarchy = JSON.parse(@facilityHierarchyJSON)
  facilityHierarchy.each do |district,facilityList|
    if facilityList.include?(facility) then
      return district
    end
  end
  return nil
end

usersByDistrict = {}
@db.view('zanzibar/byCollection?key=' + CGI.escape('"user"'))['rows'].each do |user|
  user = user["value"]
  usersByDistrict[user["district"]] = [] unless usersByDistrict[user["district"]]
  usersByDistrict[user["district"]].push(user)
end

@db.view("zanzibar/rawNotificationsSMSNotSent?include_docs=true")['rows'].each do |notification|
  notification = notification["doc"]

  district = districtByFacility(notification["hf"])
  users = usersByDistrict[district] unless district.nil?

  if users.nil? or district.nil?
    puts "Can not find user for this notification: #{notification.inspect}"
  else
    users.each do |user| 
      phone_number = user["_id"].sub(/user\./,"")
      message = "New case, press get data on Coconut Surveillance and proceed to #{notification["hf"]}"
      puts "Send '#{message}' message to #{phone_number} at #{Time.now}" 
      puts "Net::HTTP.get_response(#{"https://paypoint.selcommobile.com/bulksms/dispatch.php?msisdn=#{phone_number}&user=zmcp&password=i2e890&message=#{message}"})"
    end
    notification['SMSSent'] = true
    puts "Saving notification with SMSSent = true : #{notification.inspect}"
    #puts @db.save_doc(notification)
  end
end


