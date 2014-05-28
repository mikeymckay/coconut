/** Configure the database **/
Backbone.couch_connector.config.db_name = "zanzibar";
Backbone.couch_connector.config.ddoc_name = "zanzibar";
// If set to true, the connector will listen to the changes feed
// and will provide your models with real time remote updates.
// But in this case we enable the changes feed for each Collection on our own.
Backbone.couch_connector.config.global_changes = false;

// Added to enable saving maps
L_PREFER_CANVAS = true;
