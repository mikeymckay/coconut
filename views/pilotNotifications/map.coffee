(doc) ->
  # Only emit when we identify a new malaria case
  emit(doc.date, doc.caseid) if doc.source is "parallel sim" or doc.source is "textit"

