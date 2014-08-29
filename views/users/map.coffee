(doc) ->
  if doc.collection and doc.collection is "user"
    emit doc.district, [doc.name, doc._id.substring(5)]
