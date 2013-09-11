(doc) ->

  for value in doc

    ignored = ["collection", "complete", "couchapp"]
    notIgnored = not value in ignored

    notCouch = value.indexOf("_") != 0

    emit value, doc[value] if notIgnored and notCouch
