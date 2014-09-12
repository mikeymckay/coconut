(document) ->
  lat = document["HouseholdLocation-latitude"]
  long = document["HouseholdLocation-longitude"]
  if lat? and long?
    emit document.createdAt, [parseFloat(lat).toFixed(4),parseFloat(long).toFixed(4)]
    return

    # NOTE NONE OF THE CODE BELOW IS EVER REACHED
    # keeping this around in case I want a rough sort by promiximty
     
    # absolute value
    if lat[0] is '-'
      lat = lat.substr(1)
    if long[0] is '-'
      long = long.substr(1)

    # line up the numbers by decimal point
    while lat.indexOf(".") < long.indexOf(".")
      lat = "0" + lat

    while long.indexOf(".") < lat.indexOf(".")
      long = "0" + long

    lat = lat.substr(0,lat.indexOf(".")+5)
    long = long.substr(0,long.indexOf(".")+5)


    # zip them together
    returnValue = ""
    for throwaway,index in long
      if lat[index] != '.'
        # add trailing zeros if needed
        returnValue = returnValue + (lat[index]||"0") + (long[index]||"0")
    
    emit returnValue,[lat,long]

