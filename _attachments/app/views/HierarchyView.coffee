class HierarchyView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
      #{
        if @class.name is "WardHierarchy"
          "
            This is the format for the hierarchy. Note that a comma must separate every item unless it is the last item in a section. Coconut will warn you and not save if the format is invalid. Copy and paste the contents to <a href='http://jsonlint.com'>jsonlint</a> if you are having trouble getting the formatting correct.
      
         <h3>Ward/Shehia Hierarchy</h3>       

            <pre>
            REGION: {<br/>
                DISTRICT: {<br/>
                    CONSTITUAN: [<br/>
                        SHEHIA/WARD<br/>
                    ]<br/>
                }<br/>
            }<br/>
            </pre>
        "
        else
          "
           <h3>Facility Hierarchy</h3>       
         "

      }
        <textarea style='width:100%; height:200px;' id='hierarchy_json'>
        </textarea>
        <br/>
        <button id='save' type='button'>Save</button>
        <div id='message'></div>
    "
    $('textarea').val JSON.stringify(@class.hierarchy, undefined, 2)

  events:
    "click #save": "save"

  save: ->
    # check json
    hierarchy_json = $("#hierarchy_json").val()
    try
      JSON.parse hierarchy_json
      hierarchy = new @class()
      hierarchy.fetch
        success: ->
          hierarchy.save "hierarchy", JSON.parse(hierarchy_json)
        error: ->
          alert "Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help"
    catch error
      alert "Hierarchy is not valid. Check for missing or extra commas. Pasting it into http://jsonlint.com can help"
    # save it
