// Generated by CoffeeScript 1.9.0
(function(document) {
  var name, _i, _j, _len, _len1, _ref, _ref1, _results;
  if (document.collection === "result") {
    if (document.question === "Case Notification") {
      _ref = document.Name.split(/\s+/);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        emit(name, null);
      }
    }
    if (document.question === "Facility") {
      if ((document.FirstName != null) && document.FirstName !== "") {
        emit(document.FirstName.trim(), null);
      }
      if ((document.MiddleName != null) && document.MiddleName !== "") {
        emit(document.MiddleName.trim(), null);
      }
      if ((document.LastName != null) && document.LastName !== "") {
        emit(document.LastName.trim(), null);
      }
    }
  }
  if (document.hf) {
    if ((document.name != null) && document.name !== "") {
      _ref1 = document.name.split(/\s+/);
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        name = _ref1[_j];
        if ((document.name != null) && document.name !== "") {
          _results.push(emit(name, null));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    }
  }
});

//# sourceMappingURL=map.js.map
