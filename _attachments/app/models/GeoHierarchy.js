var GeoHierarchy,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

GeoHierarchy = (function(_super) {
  __extends(GeoHierarchy, _super);

  function GeoHierarchy() {
    return GeoHierarchy.__super__.constructor.apply(this, arguments);
  }

  GeoHierarchy.prototype.initialize = function() {
    return this.set({
      _id: "Geo Hierarchy"
    });
  };

  GeoHierarchy.prototype.url = "/geoHierarchy";

  GeoHierarchy.levels = ["REGION", "DISTRICT", "SHEHIA"];

  GeoHierarchy.swahiliDistrictName = function(district) {
    return GeoHierarchy.englishToSwahiliDistrictMapping[district] || district;
  };

  GeoHierarchy.load = function(options) {
    var geoHierarchy;
    geoHierarchy = new GeoHierarchy();
    return geoHierarchy.fetch({
      success: function() {
        var addChildren, addLevelProperties;
        GeoHierarchy.hierarchy = geoHierarchy.get("hierarchy");
        GeoHierarchy.root = {
          parent: null
        };
        addLevelProperties = function(node) {
          var levelClimber;
          levelClimber = node;
          node[levelClimber.level] = levelClimber.name;
          while (levelClimber.parent !== null) {
            levelClimber = levelClimber.parent;
            node[levelClimber.level] = levelClimber.name;
          }
          return node;
        };
        addChildren = function(node, values, levelNumber) {
          var key, result, value;
          if (_(values).isArray()) {
            node.children = (function() {
              var _i, _len, _results;
              _results = [];
              for (_i = 0, _len = values.length; _i < _len; _i++) {
                value = values[_i];
                result = {
                  parent: node,
                  level: this.levels[levelNumber],
                  name: value,
                  children: null
                };
                _results.push(result = addLevelProperties(result));
              }
              return _results;
            }).call(GeoHierarchy);
            return node;
          } else {
            node.children = (function() {
              var _results;
              _results = [];
              for (key in values) {
                value = values[key];
                result = {
                  parent: node,
                  level: this.levels[levelNumber],
                  name: key
                };
                result = addLevelProperties(result);
                _results.push(addChildren(result, value, levelNumber + 1));
              }
              return _results;
            }).call(GeoHierarchy);
            return node;
          }
        };
        addChildren(GeoHierarchy.root, GeoHierarchy.hierarchy, 0);
        return $.couch.db(Coconut.config.database_name()).openDoc("district_language_mapping", {
          success: function(result) {
            GeoHierarchy.englishToSwahiliDistrictMapping = result.english_to_swahili;
            return options.success();
          },
          error: function(error) {
            console.error("Error loading district_language_mapping: " + (JSON.stringify(error)));
            return options.error(error);
          }
        });
      },
      error: function(error) {
        console.error("Error loading Geo Hierarchy: " + (JSON.stringify(error)));
        return options.error(error);
      }
    });
  };

  GeoHierarchy.findInNodes = function(nodes, requiredProperties) {
    var node, results;
    results = _(nodes).where(requiredProperties);
    if (_(results).isEmpty()) {
      if (nodes != null) {
        results = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = nodes.length; _i < _len; _i++) {
            node = nodes[_i];
            _results.push(GeoHierarchy.findInNodes(node.children, requiredProperties));
          }
          return _results;
        })();
      }
      results = _.chain(results).flatten().compact().value();
      if (_(results).isEmpty()) {
        return [];
      }
    }
    return results;
  };

  GeoHierarchy.find = function(name, level) {
    return GeoHierarchy.findInNodes(GeoHierarchy.root.children, {
      name: name,
      level: level
    });
  };

  GeoHierarchy.findAllForLevel = function(level) {
    return GeoHierarchy.findInNodes(GeoHierarchy.root.children, {
      level: level
    });
  };

  GeoHierarchy.findChildrenNames = function(targetLevel, parentName) {
    var indexOfTargetLevel, nodeResult, parentLevel;
    indexOfTargetLevel = _(this.levels).indexOf(targetLevel);
    parentLevel = this.levels[indexOfTargetLevel - 1];
    nodeResult = GeoHierarchy.findInNodes(GeoHierarchy.root.children, {
      name: parentName,
      level: parentLevel
    });
    if (_(nodeResult).isEmpty()) {
      return [];
    }
    if (nodeResult.length > 2) {
      console.error("More than one match");
    }
    return _(nodeResult[0].children).pluck("name");
  };

  GeoHierarchy.findAllDescendantsAtLevel = function(name, sourceLevel, targetLevel) {
    var getLevelDescendants, sourceNode;
    getLevelDescendants = function(node) {
      var childNode;
      if (node.level === targetLevel) {
        return node;
      }
      return (function() {
        var _i, _len, _ref, _results;
        _ref = node.children;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          childNode = _ref[_i];
          _results.push(getLevelDescendants(childNode));
        }
        return _results;
      })();
    };
    sourceNode = GeoHierarchy.find(name, sourceLevel);
    return _.flatten(getLevelDescendants(sourceNode[0]));
  };

  GeoHierarchy.findShehia = function(targetShehia) {
    return GeoHierarchy.find(targetShehia, "SHEHIA");
  };

  GeoHierarchy.findOneShehia = function(targetShehia) {
    var shehia;
    shehia = GeoHierarchy.findShehia(targetShehia);
    switch (shehia.length) {
      case 0:
        return null;
      case 1:
        return shehia[0];
      default:
        return console.error("Multiple Shehia's found for " + targetShehia);
    }
  };

  GeoHierarchy.findAllShehiaNamesFor = function(name, level) {
    return _.pluck(GeoHierarchy.findAllDescendantsAtLevel(name, level, "SHEHIA"), "name");
  };

  GeoHierarchy.allDistricts = function() {
    return _.pluck(GeoHierarchy.findAllForLevel("DISTRICT"), "name");
  };

  GeoHierarchy.allShehias = function() {
    return _.pluck(GeoHierarchy.findAllForLevel("SHEHIA"), "name");
  };

  GeoHierarchy.allUniqueShehiaNames = function() {
    return _(_.pluck(GeoHierarchy.findAllForLevel("SHEHIA"), "name")).uniq();
  };

  GeoHierarchy.all = function(geographicHierarchy) {
    return _.pluck(GeoHierarchy.findAllForLevel(geographicHierarchy.toUpperCase()), "name");
  };

  return GeoHierarchy;

})(Backbone.Model);
