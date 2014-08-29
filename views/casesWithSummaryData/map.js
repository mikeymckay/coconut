// Generated by CoffeeScript 1.7.1
(function(doc) {
  var date, lastTransfer, match;
  if (doc.MalariaCaseID) {
    date = doc.DateofPositiveResults || doc.lastModifiedAt;
    match = date.match(/^(\d\d).(\d\d).(2\d\d\d)/);
    if (match != null) {
      date = "" + match[3] + "-" + match[2] + "-" + match[1];
    }
    if (doc.transferred != null) {
      lastTransfer = doc.transferred[doc.transferred.length - 1];
    }
    if (date.match(/^2\d\d\d\-\d\d-\d\d/)) {
      emit(date, [doc.MalariaCaseID, doc.question, doc.complete, lastTransfer]);
    }
  }
  if (doc.caseid) {
    if (document.transferred != null) {
      lastTransfer = doc.transferred[doc.transferred.length - 1];
    }
    if (doc.date.match(/^2\d\d\d\-\d\d-\d\d/)) {
      return emit(doc.date, [doc.caseid, "Facility Notification", null, lastTransfer]);
    }
  }
});

//# sourceMappingURL=map.map
