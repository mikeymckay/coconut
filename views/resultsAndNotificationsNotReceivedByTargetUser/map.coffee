(document) ->
  if document.transferred?
    lastTransfer = document.transferred[document.transferred.length-1]
    if lastTransfer.received is false
      malariaCaseID =
        if document.MalariaCaseID?
          document.MalariaCaseID
        else if document.caseid?
          document.caseid

      emit lastTransfer.to, [lastTransfer.from, malariaCaseID]
