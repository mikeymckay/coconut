class CleanView extends Backbone.View
  initialize: ->
    @question = new Question()

  el: '#content'

  render: (args) =>
    @args = args

    if @args is "undo"
      throw "Must be admin" unless User.currentUser.username() is "admin"
      rc = new ResultCollection()
      rc.fetch
        include_docs: true
        success: ->
          changed_results = rc.filter  (result) ->
            (result.get("user") is "reports") and (result.get("question") is "Household Members")
          _.each changed_results, (result) ->
            $.couch.db(Coconut.config.database_name()).openDoc result.id,
              revs_info: true
            ,
              success: (doc) ->
                $.couch.db(Coconut.config.database_name()).openDoc result.id,
                  rev: doc._revs_info[1].rev #1 gives us the previous revision
                ,
                  success: (previousDoc) ->
                    newDoc = previousDoc
                    newDoc._rev = doc._rev
                    result.save newDoc

      return


    @total = 0
    @$el.html "
      <h1>The following data requires cleaning</h1>
      <h2>Duplicates (<span id='total'></span>)</h2>
      <a href='#clean/apply_duplicates'<button>Apply Recommended Duplicate Fixes</button></a>

      <div id='missingResults'>
        <table class='tablesorter'>
          <thead>
            <th>Question</th>
            <th>Case ID</th>
            <th>Patient Name</th>
            <th>Health Facility</th>
          </thead>
          <tbody/>
        </table>
      </div>

      <div id='duplicates'>
        <table>
          <thead>
            <th>Duplicates</th>
          </thead>
          <tbody>
        </table>
      </div>
      <h2>Dates (<span id='total'></span>)</h2>
      <a href='#clean/apply_dates'<button>Apply Recommended Date Fixes</button></a>
      <div id='dates'>
        <table>
        </table>
      </div>
      <h2>CaseIDS (<span id='total'></span>)</h2>
      <a href='#clean/apply_caseIDs'<button>Apply Recommended CaseID Fixes</button></a>
      <div id='caseIDs'>
        <table>
          <thead>
            <th>Current</th>
            <th>Recommendation</th>
          </thead>
          <tbody>
        </table>
      </div>
    "

    problemCases = {}

    reports = new Reports()
    reports.casesAggregatedForAnalysis
      startDate: "2012-07-01"
      endDate: "2013-08-01"
      mostSpecificLocation:
        name: "ALL"
      success: (data) =>
        _.each "missingCaseNotification,missingUssdNotification,casesNotFollowedUp".split(/,/), (issue) ->
          _.each data.followupsByDistrict.ALL[issue], (malariaCase) ->
            unless problemCases[malariaCase.caseID]?
              problemCases[malariaCase.caseID] = {}
              problemCases[malariaCase.caseID]["problems"] = []
              problemCases[malariaCase.caseID]["malariaCase"] = malariaCase
            problemCases[malariaCase.caseID]["problems"].push issue
    



        $("#missingResults tbody").append _.map(problemCases, (data, caseID) ->
          "
            #{
              res = _.map(data.malariaCase.caseResults, (result) ->
                switch result["question"]
                  when "Facility"
                    "
                    <tr>
                    <td>
                      #{result.question}
                    </td>
                    <td>
                      <a href='#show/case/#{result.MalariaCaseID}'>#{result.MalariaCaseID}</a>
                    </td>
                    <td>
                      #{result["FirstName"]} #{result["LastName"]}
                    </td>
                    <td>
                      #{result["FacilityName"]}
                    </td>
                    </tr>
                    "
                  when "Case Notification"
                    "
                    <tr>
                    <td>
                      #{result.question}
                    </td>
                    <td>
                      <a href='#show/case/#{result.MalariaCaseID}'>#{result.MalariaCaseID}</a>
                    </td>
                    <td>
                      #{result["Name"]}
                    </td>
                    <td>
                      #{result["FacilityName"]}
                    </td>
                    </tr>
                    "
                  else
                    if result.hf?
                      "
                      <tr>
                      <td>
                        USSD Notification
                      </td>
                      <td>
                        <a href='#show/case/#{result.caseid}'>#{result.caseid}</a>
                      </td>
                      <td>
                        #{result["name"]}
                      </td>
                      <td>
                        #{result["hf"]}
                      </td>
                      </tr>
                      "
              ).join("")
            }
          "
        ).join("")


        $("#missingResults table").tablesorter
          widgets: ['zebra']

        $("#missingResults table").addTableFilter
          labelText: null

    # 3 options: edit partials, edit complete, create new
#    @resultCollection = new ResultCollection
#    @resultCollection.fetch
#      include_docs: true
#      success: =>
#        @searchForDates()
#        @searchForManualCaseIDs()
#        @searchForDuplicates()

  searchForDuplicates: ->
    dupes = []
    found = {}
    console.log "Downloading all notifications"
    $.couch.db(Coconut.config.database_name()).view "#{Coconut.config.design_doc_name()}/notifications",
      include_docs: true
      success: (result) ->
        console.log "Searching #{result.rows.length} results"
        dupeTargets = [
          "WAMBA,SALEH"
          "WAMBA,MUHD OMI"
          "WAMBAA,KHAMIS ALI"
          "WAMBAA,KHALIDI MASOUD"
          "JUNGANI,HIDAYA MKUBWA"
          "CHANGAWENI,IBRAHIM KASIM"
          "WAMBAA,WAHIDA MBAROUK"
          "WAMBAA,KADIRU SULEIMAN"
          "SHUMBA MJIN,SHARIF"
          "MIZINGANI,SAADA MUSSA"
          "CHANGAWENI,HALIMA BAKAR"
          "WAMBAA,ALI JUMA KHAMIS"
          "WAMBAA,SLEIMAN KHAMIS"
          "MBUGUANI,AMINA ALI HAJI"
          "WAMBAA,SLEIMAN USSI"
          "SHAURIMOYO,KHAIRAT HAJI KHAMIS"
          "CHANGAWENI,MUSSA KASSIM"
          "KIPAPO,HAITHAM HAJI"
          "MICHENZANI,BIKOMBO HAKIMU"
          "MICHENZANI,ARAFA KHATIB"
          "CHANGAWENI,SAMIRA MKUBWA"
          "MICHENZANI,SALEH ABDALLA"
          "WAMBAA,MUHD OMI"

          "KUNGUNI,ZULEKHA"
          "KUNGUNI,RAYA"
          "KUNGUNI,SALAMA"
          "KUNGUNI,TALIB"
          "AMANI,ZAINAB HAROUB"
          "SHAKANI,JANET"
          "SHAKANI,PAULINA"
          "NDAGONI,ASHA"
          "KINUNI,ALI ABDALLA"
          "NYERERE,JUMA"
          "KUNGUNI,AWENA"
          "KUNGUNI,INAT"
          "KUNGUNI,ALI"
          "KIEMBE SAMAKI,NEILA SALUM ABDALLA"
          "KIEMBE SAMAKI,NEILA"
          "TONDOONI,SAID"
          "MSEWENI,ZAHARANI"
          "KUNGUNI,FAHD"
          "KUNGUNI,ALI"
          "KUNGUNI,YASIR"
          "CHONGA,FATMA"
          "KIUNGONI,ABDUL"
          "DONGE  MCHANGANI,KHADIJA"
          "KIPANGE,IHIDINA"
          "CHEJU,KHAMIS"
          "UTAANI,RAHMA"
          "TUMBE MASHARIKI,OMAR SAID OMAR"
          "MAGOGONI,FATMA  SLEIMAN"
          "NDAGONI,ARKAM"
          "MWANAKWEREKWE,MUKTAR MOHD"
          "TUNGUU,FADHIL"
          "KISAUNI,FERUZ"
          "NDAGONI,NAOMBA"
          "TUMBE MASHARIKI,RUMAIZA ALI KHAMIS"
          "KARANGE,SALUM"
          "MNYIMBI,HAMAD"
          "MNYIMBI,FATUMA"
          "MCHANGANI,MOHD"
          "M/KIDATU,MWANAISHA SALEH ALI"
          "KONDE,BIMKASI"
          "TUMBE MASHARIKI,ALI SHAURI HAJI"
          "KARANGE,MUKRIM"
          "MTMBILE,LAILATI"
          "MTAMBILE,YUSSUF"
          "MTAMBILE,MACHANO"
          "VIJIBWENI,IBAHIM"
          "MTAMBILE,HAWA"
          "MTAMBILE,ZUHURA"
          "MELI NNE,RASULI"
          "NGAMBWA,MKWABI"
          "DONGE  MCHANGANI,MAKAME"
          "OLE,OMI"
          "MKOKOTONI,SEMENI"
          "SHAKANI,HALIMA"
          "SHAKANI,FAUZIA"
          "BWELEO,MWINJUMA"
          "BWELEO,HALIMA"
          "MSUKA,SAID SALUM"
          "KANDWI,IBRAHIM"
          "KIUNGONI,HAITHAM"
          "SHARIF MSA,ZAINAB ADAMU AMIRI"
          "TONDOONI,MAKAME FAKI"
          "KIBONDENI,HAIRATI"
          "D. MCHANGANI,RIZIKI"
          "D. MCHANGANI,YUSRA"
          "UPENJA,JUMA"
          "SHAKANI,TUKENA"
          "NDAGONI,ASYA"
          "SHAKANI,KIHENGA"
          "MTAMBWE KASKAZINI,HAWA MALIK"
          "DUNGA K,SULEIMAN"
          "MIHOGONI,YUSSUF"
          "MAKANGALE,AISHA"
          "KIDANZINI,JOGHA"
          "KIDANZINI,SABRINA"
          "TUNGUU,ERNEST"
          "KIBONDENI,ASHRAK"
          "KINUNI,YUSSUF"
          "KISAUNI,MOHD OMAR KHAIID"
          "KITUMBA,HIDAYA SULEIMAN SAIDI"
          "PIKI,ISMAIL MSHAMATA"
          "KANDWI,KAZIJA"
          "K UPELE,HAJI"
          "K/UPELE,HAJI"
          "JENDELE,HAJI"
          "MWAKAJE,EMANUEL LUCAS"
          "CHUKWANI,MAIMUNA HASSAN"
          "MTANGANI,IDRISA"
          "MCHANGANI,RAMADHAN"
          "CHUWINI,AISAR"
          "CHIMBA,KHATIB ALI KHATIB"
          "JENDELE,TATU"
          "MAJENZI,KHALFANI ALI MASOUD"
          "JADIDA,TIME"
          "KIUYU MBUYUNI,BIKOMBO SALIM RASHID"
          "VITONGOJI,MAUA"
          "GOMBANI,HAFIDH"
          "MIZINGANI,KOMBO"
          "MWERA,RASHID"
          "M WERA,IDRISA"
          "KONDE,MARYAM"
          "CHUKWANI,ALI MZEE SALEH"
          "WAMBAA,MKASI KHATIB"
          "WAMBAA,SAID BARAKA"
          "WAMBAA,KADIRU SLEIMAN"
          "WAMBAA,IDRISA OTHMAN"
          "TUMBE MASHARIKI,HELENA MAULID MTAWA"
          "WAMBAA,MUHD OMI"
          "WAMBAA,IDRISA OTHMAN"
          "MFENESINI,AZIZ SULEIMAN"
          "WAMBAA,FATMA HIMID OMAR"
          "WAMBAA,FATMA HIMID OMAR"
          "WAMBAA,FATMA HIMID OMAR"
        ]
        _.each result.rows, (row) ->
          _.each dupeTargets, (value) ->
            [shehia,name] = value.split(",")
            if (row.doc.shehia is shehia and row.doc.name is name)
              if found[value]
                dupes.push row.doc
              else
                console.log "saving copy of #{JSON.stringify row.doc}"
                found[value] = true


        #deleteDoc = (dupe) ->
        #  $.couch.db(Coconut.config.database_name()).removeDoc dupe

        #debouncedDelete = _.defer(deleteDoc,500)

        console.log dupes
        i=0
        _.each dupes, (dupe) ->
          i++
          #debouncedDelete(dupe)
          #_.delay $.couch.db(Coconut.config.database_name()).removeDoc,i*200,dupe
          $.couch.db(Coconut.config.database_name()).removeDoc(dupe)



  searchForManualCaseIDs: ->
    @resultCollection.each (result) =>
      _.each _.keys(result.attributes), (key) =>
        if key.match(/MalariaCaseID/i)
          caseID = result.get(key)
          if caseID?
            unless caseID.match(/[A-Z][A-Z][A-Z]\d\d\d/)
              recommendedChange = caseID.replace(/[\ \.\-\/_]/,"")
              recommendedChange = recommendedChange.toUpperCase()

              if recommendedChange.match(/[A-Z][A-Z][A-Z]\d\d\d/)
                if @args is "apply_caseIDs"
                  throw "Must be admin" unless User.currentUser.username() is "admin"
                  result.save key,recommendedChange
              else
                recommendedChange = "Fix manually"

              $("#caseIDs tbody").append "
                <tr>
                  <td>#{caseID}</td>
                  <td>#{recommendedChange}</td>
                </tr>
              "


  searchForDates: ->
    @resultCollection.each (result) =>
      _.each _.keys(result.attributes), (key) =>
        if key.match(/date/i)
          date = result.get(key)
          if date?
            @total++
            cleanedDate = @cleanDate(date)
            unless cleanedDate[1] is "No action recommended"
              $("#dates table").append "
                <tr>
                  <td><a href='#show/case/#{result.get("MalariaCaseID")}'>#{result.get("MalariaCaseID")}</a></td>
                  <td>#{key}</td>
                  <td>#{date}</td>
                  <td>#{cleanedDate[0]}</td>
                  <td>#{cleanedDate[1]}</td>
                </tr>
              "
              if @args is "apply_dates" and cleanedDate[0]
                throw "Must be admin" unless User.currentUser.username() is "admin"
                result.save key,cleanedDate[0]

  cleanDate: (date) ->
    dateMatch = date.match /^(\d+)([ -/])(\d+)([ -/])(\d+)$/
    if dateMatch
      first = dateMatch[1]
      second = dateMatch[3]
      third = dateMatch[5]
      if second.match /201\d/
        return [null, "Invalid year"]

      if first.match /201\d/
        year = first
        if dateMatch[2] != "-"
          day = second
          month = third
          return [@format(year,month,day), "Non dash separators, not generated by tablet, can assume yy,dd,mm"]
        else
          return [null, "No action recommended"]
      else if third.match /201\d/
        day = first
        month = second
        year = third
        return [@format(year,month,day), "Year last, not generated by tablet, can assume dd,mm,yy"]
      else
        return [null, "Can't find a date"]
    else
      return [null, "Can't find a date"]

  format: (year,month,day) ->
    year = parseInt(year,10)
    month = parseInt(month,10)
    day = parseInt(day,10)
    month = "0#{month}" if month < 10
    day = "0#{day}" if day < 10
    return "#{year}-#{month}-#{day}"
