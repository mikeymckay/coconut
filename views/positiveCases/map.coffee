(document) ->
  if document.question is "Facility" and document.DateofPositiveResults
    emit document.DateofPositiveResults, document.MalariaCaseID
  if document.question is "Household Members" and document.MalariaTestResult is "PF"
    emit document.lastModifiedAt, document.MalariaCaseID
