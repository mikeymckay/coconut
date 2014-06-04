(document) ->
  # Only started using this after the 15th of Feb 2014, so ignore earlier docs
  if document.hf and not document.hasCaseNotification and document.date > "2014-02-15"
    emit document.date, document.caseid
