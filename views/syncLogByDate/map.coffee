(doc) ->
  if doc.action and (doc.action is "sendToCloud" or doc.action is "getFromCloud")
    emit doc.time, doc.user
