(document) ->
  if document.msisdn and (not document.SMSSent)
    emit document.date, null
