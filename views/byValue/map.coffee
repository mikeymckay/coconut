(doc) ->
  if doc.collection is "result"
    for value of doc
      if(value.indexOf("_") != 0 && value != "collection" && value != "complete" && value != "couchapp")
        emit value, doc[value]
