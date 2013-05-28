// Generated by CoffeeScript 1.3.1
var Message,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

Message = (function(_super) {

  __extends(Message, _super);

  Message.name = 'Message';

  function Message() {
    return Message.__super__.constructor.apply(this, arguments);
  }

  Message.prototype.url = "/message";

  Message.prototype.sendSMS = function(options) {
    var to;
    to = (this.get("to")).replace(/^07/, "2557");
    return $.ajax({
      url: 'https://paypoint.selcommobile.com/bulksms/dispatch.php',
      dataType: "jsonp",
      data: {
        user: 'zmcp',
        password: 'i2e890',
        msisdn: to,
        message: this.get("text")
      },
      success: function() {
        return options.success();
      },
      error: function(error) {
        console.log(error);
        if (error.statusText === "success") {
          return options.success();
        } else {
          return options.error(error);
        }
      }
    });
  };

  return Message;

})(Backbone.Model);
