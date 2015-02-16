(document) ->
  if document.collection is "result"
    emit document.question + ':' + document.lastModifiedAt, null
