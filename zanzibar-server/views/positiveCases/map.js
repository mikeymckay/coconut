// Generated by CoffeeScript 1.7.1
(function(document) {
  if (document.question === "Facility" && document.DateofPositiveResults) {
    emit(document.DateofPositiveResults, document.MalariaCaseID);
  }
  if (document.question === "Household Members" && document.MalariaTestResult === "PF") {
    return emit(document.lastModifiedAt, document.MalariaCaseID);
  }
});

//# sourceMappingURL=map.map
