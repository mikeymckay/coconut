(document) ->
  if document.transferred?
    lastTransfer = document.transferred[document.transferred.length-1]
    emit lastTransfer.time, (document.MalariaCaseID or document.caseid)
