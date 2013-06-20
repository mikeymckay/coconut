(doc, req) ->
  # Filters on documents with attachments seems to fail
  if (doc.collection is 'question' or doc.collection is 'user')
    return true
  else
    return false
