// Generated by CoffeeScript 1.9.0
(function(document) {
  if (document.question === "Facility" && document.DateofPositiveResults) {
    emit(document.DateofPositiveResults, document.MalariaCaseID);
  }
  if (document.question === "Household Members" && document.MalariaTestResult === "PF") {
    return emit(document.lastModifiedAt, document.MalariaCaseID);
  }
});

//# sourceMappingURL=map.js.map