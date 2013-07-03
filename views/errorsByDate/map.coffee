(doc) ->
	emit(doc.datetime, null) if doc.collection is "error" and doc.datetime
