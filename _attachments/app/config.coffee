### Configuration ###

Backbone.couch_connector.config.db_name = "zanzibar"
Backbone.couch_connector.config.ddoc_name = "zanzibar"
Backbone.couch_connector.config.global_changes = false

# Added to enable saving maps
L_PREFER_CANVAS = true

Coconut = {}

Coconut.debug = (string) ->
  console.log string
  $("#log").append string + "<br/>"

Coconut.identifyingAttributes = [
  "Name"
  "name"
  "FirstName"
  "MiddleName"
  "LastName"
  "ContactMobilepatientrelative"
  "HeadofHouseholdName"
  "ShehaMjumbe"
]

Coconut.IRSThresholdInMonths = 6
