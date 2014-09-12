(doc) ->
  emit("#{doc.MalariaCaseID}-#{doc.question}",null) if doc.MalariaCaseID
  emit("#{doc.caseid}-USSD Notification",null) if doc.caseid
