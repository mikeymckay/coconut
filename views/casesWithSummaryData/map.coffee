(doc) ->
  if doc.MalariaCaseID
    date = doc.DateofPositiveResults or doc.lastModifiedAt
    match = date.match(/^(\d\d).(\d\d).(2\d\d\d)/)
    if match?
      date = "#{match[3]}-#{match[2]}-#{match[1]}"

    if doc.transferred?
      lastTransfer = doc.transferred[doc.transferred.length-1]

    if date.match(/^2\d\d\d\-\d\d-\d\d/)
      emit date, [doc.MalariaCaseID,doc.question,doc.complete,lastTransfer]

  if doc.caseid
    if doc.transferred?
      lastTransfer = doc.transferred[doc.transferred.length-1]
    if doc.date.match(/^2\d\d\d\-\d\d-\d\d/)
      emit doc.date, [doc.caseid, "Facility Notification", null, lastTransfer]
