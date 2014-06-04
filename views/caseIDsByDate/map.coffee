(doc) ->
  # Only emit when we identify a new malaria case
  return if doc.source is "parallel sim"
  return if doc.source is "textit"
  emit(doc.DateofPositiveResults, doc.MalariaCaseID) if doc.DateofPositiveResults
  emit(doc.lastModifiedAt, doc.MalariaCaseID) if doc.MalariaTestResult is "PF" or doc.MalariaTestResult is "Mixed"
  emit(doc.date, doc.caseid) if doc.caseid
