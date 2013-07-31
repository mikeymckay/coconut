# Configure the database based on current URL
matchResults = document.location.pathname.match(/^\/(.*)\/_design\/(.*?)\//)

Backbone.couch_connector.config.db_name = matchResults[1]
Backbone.couch_connector.config.ddoc_name = matchResults[2]
Backbone.couch_connector.config.global_changes = false

# Can't get this to work yet
#Backbone.sync = BackbonePouch.sync
#  db: Pouch('coconut.0.12')
