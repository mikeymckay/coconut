(doc) ->
  emit(doc.ClientID, null) if doc.ClientID
  if doc.IDLabel
    id = doc.IDLabel.replace(/-|\n/g,"")
    if id != ""
      emit id, null
