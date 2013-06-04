// Generated by CoffeeScript 1.6.2
var ScanBarcodeView, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ScanBarcodeView = (function(_super) {
  __extends(ScanBarcodeView, _super);

  function ScanBarcodeView() {
    this.render = __bind(this.render, this);    _ref = ScanBarcodeView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  ScanBarcodeView.prototype.el = '#content';

  ScanBarcodeView.prototype.events = {
    "change .client": "onChange"
  };

  ScanBarcodeView.prototype.render = function() {
    this.$el.html("      <style>      #feedback      {        color: #cc0000;      }      </style>      <h1>Find/Create Patient</h1>          <span id='feedback'></span>      <br>      <div>        <label class='client' for='client_1'>Client ID</label>        <input class='client' id='client_1' type='text'>      </div>      <div>        <label class='client' for='client_2'>Confirm client ID</label>        <input class='client' id='client_2' type='text'>      </div>    ");
    return $("input").textinput();
  };

  ScanBarcodeView.prototype.onChange = function() {
    var client1, client2;

    client1 = $("#client_1").val();
    client2 = $("#client_2").val();
    if (client1 !== "" && client2 !== "") {
      if (client1 !== client2) {
        return $("#feedback").html("Client IDs do not match");
      } else {
        Coconut.loginView.callback = {
          success: function() {
            return Coconut.router.navigate("/summary/" + client1, true);
          }
        };
        return Coconut.loginView.render();
      }
    }
  };

  return ScanBarcodeView;

})(Backbone.View);

/*
//@ sourceMappingURL=ScanBarcodeView.map
*/
