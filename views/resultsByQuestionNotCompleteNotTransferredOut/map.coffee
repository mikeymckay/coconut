(document) ->
  if document.collection is "result"
    if document.complete isnt "true"
      if document.transferred?
        emit document.question, document.transferred[document.transferred.length-1].to
      else
        emit document.question, null
