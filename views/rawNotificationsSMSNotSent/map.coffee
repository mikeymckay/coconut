(doc) ->
  if doc.hf and (not doc.SMSSent)
    if doc.source? and (doc.source is "parallel sim" or doc.source is "textit")
      # Do nothing
    else
      emit doc.date, null
