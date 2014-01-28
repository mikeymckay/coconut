(doc) ->
  ###
  if doc.IDLabel and doc.IDLabel != ""
    if doc.VisitDate or doc.fDate
      visitDate = doc.VisitDate if doc.VisitDate
      visitDate = doc.fDate if doc.fDate
      dateData = visitDate.match(/(\d+)\/(\d+)\/(\d+)/)
      year = dateData[3]
      month = dateData[1]
      month = "0#{month}" if month.length is 1
      day = dateData[2]
      day = "0#{day}" if day.length is 1
      visitDate = "#{year}-#{month}-#{day}"
      emit visitDate, doc.IDLabel
  emit(doc.createdAt, doc.ClientID) if doc.ClientID
  ###
  if doc.IDLabel and doc.IDLabel != ""
    emit(doc.VisitDate, doc.IDLabel) if doc.VisitDate
    emit(doc.fDate, doc.IDLabel) if doc.fDate
  emit(doc.createdAt, doc.ClientID) if doc.ClientID
