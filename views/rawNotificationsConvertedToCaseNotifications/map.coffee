(document) ->
  if document.msisdn and document.hasCaseNotification
    emit document.date, null
