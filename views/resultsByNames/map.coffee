(document) ->
  if document.collection is "result"
    if document.question is "Case Notification"
      for name in document.Name.split(/\s+/)
        emit name, null
    if document.question is "Facility"
      emit(document.FirstName.trim(), null) if document.FirstName? and document.FirstName != ""
      emit(document.MiddleName.trim(), null) if document.MiddleName? and  document.MiddleName != ""
      emit(document.LastName.trim(), null) if document.LastName? and document.LastName != ""
  if document.hf
    if document.name? and document.name != ""
      for name in document.name.split(/\s+/)
        emit(name, null) if document.name? and document.name != ""
