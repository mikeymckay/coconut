(doc) ->
  emit(doc.ClientID, null) if doc.ClientID
  if doc.IDLabel
    if doc.IDLabel != ""
      emit doc.IDLabel, null
