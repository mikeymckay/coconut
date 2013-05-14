// Generated by CoffeeScript 1.3.3
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
    var _ref;
    this.$el.html("      <form id='local-config'>        <h1>Configure your Coconut system</h1>        <label>Coconut Cloud URL</label>        <input type='text' name='coconut-cloud' value='http://'></input>        <fieldset id='mode-fieldset'>          <legend>Mode</legend>            <label for='cloud'>Cloud (reporting system)</label>            <input id='cloud' name='mode' type='radio' value='cloud'></input>            <label for='mobile'>Mobile (data collection, probably on a tablet)</label>            <input id='mobile' name='mode' type='radio' value='mobile'></input>        </fieldset>        <label>HTTP post target</label>        <input type='text' name='http-post-target' value=''></input>        <button>Save</button>        <div id='message'></div>      </form>    ");
    if (Coconut.config.get("mode") == null) {
      $("#mode-fieldset").hide();
      $("#mobile").prop("checked", true);
    }
    this.$el.find('input[type=radio],input[type=checkbox]').checkboxradio();
    this.$el.find('button').button();
    this.$el.find('input[type=text]').textinput();
    return (_ref = Coconut.config.local) != null ? _ref.fetch({
      success: function() {
        return js2form($('#local-config').get(0), Coconut.config.local.toJSON());
      },
      error: function() {
        return $('#message').html("Complete the fields before continuing");
      }
    }) : void 0;
  };

  LocalConfigView.prototype.events = {
    "click #local-config button": "save"
  };

  LocalConfigView.prototype.save = function() {
    var coconutCloud, coconutCloudConfigURL, localConfigFromForm;
    localConfigFromForm = $('#local-config').toObject();
    coconutCloud = $("input[name=coconut-cloud]").val();
    coconutCloudConfigURL = "" + coconutCloud + "/coconut.config";
    if (localConfigFromForm.mode && (coconutCloud != null)) {
      $('#message').html("Downloading configuration file from " + coconutCloudConfigURL + "<br/>");
      $.ajax({
        url: coconutCloudConfigURL,
        dataType: "jsonp",
        success: function(cloudConfig) {
          $('#message').append("Saving configuration file<br/>");
          delete cloudConfig["_rev"];
          return Coconut.config.save(cloudConfig, {
            success: function() {
              var localConfig;
              $('#message').append("Creating local configuration file<br/>");
              localConfig = new LocalConfig();
              return localConfig.fetch({
                complete: function() {
                  return localConfig.save(localConfigFromForm, {
                    success: function() {
                      var sync;
                      $('#message').append("Local configuration file saved<br/>");
                      sync = new Sync();
                      return sync.save(null, {
                        success: function() {
                          $('#message').append("Updating application<br/>");
                          return sync.getFromCloud({
                            success: function() {
                              Coconut.router.navigate("", false);
                              return location.reload();
                            }
                          });
                        }
                      });
                    }
                  });
                }
              });
            }
          });
        },
        error: function(error) {
          return console.log("Couldn't find config file at " + coconutCloudConfigURL);
        }
      });
      return false;
    } else {
      $('#message').html("Fields incomplete");
      return false;
    }
  };

  return LocalConfigView;

})(Backbone.View);
