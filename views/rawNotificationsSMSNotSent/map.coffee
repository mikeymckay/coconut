(doc) ->
  if doc.hf and (not doc.SMSSent)
    emit doc.date, null
