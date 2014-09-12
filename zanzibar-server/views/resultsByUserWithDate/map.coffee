(document) ->
  if document.collection is "result"
    emit document.user, document.lastModifiedAt
