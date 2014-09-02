class HierarchyView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
      #{
        if @class.name is "GeoHierarchy"
          "
            This is the format for the hierarchy. Note that a comma must separate every item unless it is the last item in a section. Coconut will warn you and not save if the format is invalid. Copy and paste the contents to <a href='http://jsonlint.com'>jsonlint</a> if you are having trouble getting the formatting correct.
      
         <h3>Geo Hierarchy</h3>       

            <pre>
            REGION: {<br/>
                DISTRICT: [<br/>
                      SHEHIA<br/>
                    ]<br/>
            }<br/>
            </pre>
        "
        else
          "
           <h3>Facility Hierarchy</h3>
           <div id='jsoneditor' style='width: 400px; height: 400px;'></div>
           Click on the district to select a facility<br/>
          #{
            _.map FacilityHierarchy.allDistricts(), (district) ->
              "
              <a onClick='$(\"##{district}-facilities\").toggle()' href='#edit/hierarchy/district/#{district}'>#{district}</a>
              <div id='#{district}-facilities' style='display:none;width:50%'>
                #{
                  sortedFacilities = _(FacilityHierarchy.hierarchy[district]).sortBy (facility) -> facility.facility
                  _.map sortedFacilities, (facility) ->
                    "<a href='#edit/hierarchy/facility/district/#{district}/facility/#{facility.facility}'>#{facility.facility}</a>"
                  .join("")
                }
              </div>
              "
            .join("")
           }
          "

        }
        <textarea style='width:100%; height:200px;' id='hierarchy_json'>
        </textarea>
        <br/>
        <button id='save' type='button'>Save</button>
        <div id='message'></div>
    "
    $('textarea').val JSON.stringify(@class.hierarchy, undefined, 2)
    editor = new JSONEditor document.getElementById('jsoneditor'),
      mode: "tree"
    editor.set @class.hierarchy
    $("a").button()

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
