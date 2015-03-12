// Generated by CoffeeScript 1.9.1
(function(document) {
  var lastTransfer, malariaCaseID;
  if (document.transferred != null) {
    lastTransfer = document.transferred[document.transferred.length - 1];
    if (lastTransfer.received === false) {
      malariaCaseID = document.MalariaCaseID != null ? document.MalariaCaseID : document.caseid != null ? document.caseid : void 0;
      return emit(lastTransfer.to, [lastTransfer.from, malariaCaseID]);
    }
  }
});

//# sourceMappingURL=map.js.map
