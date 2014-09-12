(doc) ->
  if doc.type is "Weekly Facility Report"
# Make sure to prepend 0 for single digit weeks
    key = doc["_id"].split(/-/)
    key[1] = ('0'+key[1]).slice(-2)
    emit(key,doc["Submit Date"])
