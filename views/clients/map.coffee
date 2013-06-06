(doc) ->
  emit(doc.ClientID, null) if doc.ClientID
  if doc.IDLabel
    if IDLabel != ""
      emit id, null
