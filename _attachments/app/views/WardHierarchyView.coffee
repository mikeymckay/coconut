class WardHierarchyView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
        This is the format for the shehia hierarchy. Note that a comma must separate every item unless it is the last item in a section. Coconut will warn you and not save if the format is invalid. Copy and paste the contents to <a href='http://jsonlint.com'>jsonlint</a> if you are having trouble getting the formatting correct.
        <pre>
        REGION: {<br/>
            DISTRICT: {<br/>
                CONSTITUAN: [<br/>
                    SHEHIA/WARD<br/>
                ]<br/>
            }<br/>
        }<br/>
        </pre>
        <textarea style='width:100%; height:200px;' id='wardHierarchy_json'>
        </textarea>
        <br/>
        <button id='save' type='button'>Save</button>
        <div id='message'></div>
    "
    $('textarea').val JSON.stringify(WardHierarchy.hierarchy, undefined, 2)

  events:
    "click #save": "save"

  save: ->
    # check json
    wardHierarchy_json = $("#wardHierarchy_json").val()
    try
      JSON.parse wardHierarchy_json
      wardHierarchy = new WardHierarchy()
      wardHierarchy.fetch
        success: ->
          wardHierarchy.save "hierarchy", JSON.parse(wardHierarchy_json)
        error: ->
          alert "Ward Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help"
    catch error
      alert "Ward Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help"
    # save it
