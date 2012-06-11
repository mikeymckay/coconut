(doc, req) ->
  if (doc.collection is 'question' or doc.collection is 'user'or doc._id is '_design/zanzibar')
    return true
  else
    return false
