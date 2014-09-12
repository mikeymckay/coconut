(document) ->
  if document.collection is "result" and document.lastModifiedAt? and document.user? and document.MalariaCaseID?
    emit document.lastModifiedAt, [document.user,document.MalariaCaseID]
