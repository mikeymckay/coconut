// Generated by CoffeeScript 1.6.2
(function(document) {
  var index, lat, long, returnValue, throwaway, _i, _len;

  lat = document["HouseholdLocation-latitude"];
  long = document["HouseholdLocation-longitude"];
  if ((lat != null) && (long != null)) {
    emit(document.createdAt, [parseFloat(lat).toFixed(4), parseFloat(long).toFixed(4)]);
    return;
    if (lat[0] === '-') {
      lat = lat.substr(1);
    }
    if (long[0] === '-') {
      long = long.substr(1);
    }
    while (lat.indexOf(".") < long.indexOf(".")) {
      lat = "0" + lat;
    }
    while (long.indexOf(".") < lat.indexOf(".")) {
      long = "0" + long;
    }
    lat = lat.substr(0, lat.indexOf(".") + 5);
    long = long.substr(0, long.indexOf(".") + 5);
    returnValue = "";
    for (index = _i = 0, _len = long.length; _i < _len; index = ++_i) {
      throwaway = long[index];
      if (lat[index] !== '.') {
        returnValue = returnValue + (lat[index] || "0") + (long[index] || "0");
      }
    }
    return emit(returnValue, [lat, long]);
  }
});

/*
//@ sourceMappingURL=map.map
*/