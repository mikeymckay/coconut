var LocalConfigView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

LocalConfigView = (function(_super) {
  __extends(LocalConfigView, _super);

  function LocalConfigView() {
    return LocalConfigView.__super__.constructor.apply(this, arguments);
  }

  LocalConfigView.prototype.el = '#content';

  LocalConfigView.prototype.render = function() {
    this.$el.html("<form id='local-config'> <fieldset> <legend>Mode</legend> <label for='cloud'>Cloud (reporting system)</label> <input id='cloud' name='mode' type='radio' value='cloud'></input> <label for='mobile'>Mobile (data collection, probably on a tablet)</label> <input id='mobile' name='mode' type='radio' value='mobile'></input> </fieldset> <button>Save</button> <div id='message'></div> </form>");
    this.$el.find('input[type=radio],input[type=checkbox]').checkboxradio();
    this.$el.find('button').button();
    return Coconut.config.local.fetch({
      success: function() {
        return js2form($('#local-config').get(0), Coconut.config.local.toJSON());
      },
      error: function() {
        return $('#message').html("Complete the fields before continuing");
      }
    });
  };

  LocalConfigView.prototype.events = {
    "click #local-config button": "save"
  };

  LocalConfigView.prototype.save = function() {
    var result;
    result = $('#local-config').toObject();
    if (result.mode) {
      Coconut.config.local.save(result, {
        success: function() {
          Coconut.router.navigate("", false);
          return location.reload();
        }
      });
    } else {
      $('#message').html("Fields incomplete");
    }
    return false;
  };

  return LocalConfigView;

})(Backbone.View);
