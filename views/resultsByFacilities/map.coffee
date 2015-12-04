(document) ->
  if document.collection is "result"
    if document.question is "Case Notification"
      emit(document.FacilityName, null)
    if document.question is "Facility"
      emit(document.FacilityName, null)
  if document.hf
    emit(document.hf, null)
