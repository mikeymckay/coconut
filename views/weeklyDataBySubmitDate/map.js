// Generated by CoffeeScript 1.9.1
(function(doc) {
  var key;
  if (doc.type === "Weekly Facility Report") {
    key = doc["_id"].split(/-/);
    key[1] = ('0' + key[1]).slice(-2);
    return emit(key, doc["Submit Date"]);
  }
});

//# sourceMappingURL=map.js.map
