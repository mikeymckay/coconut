class ScanBarcodeView extends Backbone.View

  el: '#content'

  events:
    "change #barcode" : "handleBarcode"

  render: =>
    @$el.html "
      <h1>Scan Client Barcode</h1>
      <input id='barcode' name='barcode' type='text'></input>
    "

  handleBarcode: ->
    barcodeValue = $("[name=barcode]").val()
    Coconut.loginView.callback =
      success: ->
        Coconut.router.navigate("/summary/#{barcodeValue}",true)
    Coconut.loginView.render()
