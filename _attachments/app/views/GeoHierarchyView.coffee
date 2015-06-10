class GeoHierarchyView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
      <h1>Shehia Management</h1>
      <div style='float:right'>
        <div id='search-result'></div>
        Search by Shehia
        <input id='search'></input>
      </div>
      Select a region and district to update shehias<br/>
      <br/>
      Region: 
        <select id='region'>
          <option></option>
          #{
            _(GeoHierarchy.allRegions()).map (region) ->
              "<option>#{region}</option>"
            .join ""
          }
        </select>
      District:
        <select id='district'>
        </select>
      <br/>  
      <div id='shehias-box' style='display:none'>
        Shehias:
          <textarea style='width:100%; height:400px;' id='shehias'>
          </textarea>
      </div>

      <br/>
      <button id='save' type='button'>Save</button>
      <br/>


      <div id='message'></div>
    "
    $("a").button()

    $("#search").typeahead
      local: GeoHierarchy.allShehias()
    .on "typeahead:selected", @search

  events:
    "click #save": "save"
    "change #region": "changeRegion"
    "change #district": "changeDistrict"

  search: ->
    shehia = GeoHierarchy.findShehia $("#search").val()
    if shehia.length >= 1
      shehia = shehia[0]
    $("#search-result").html "
      Region: #{shehia.REGION}<br/>
      District: #{shehia.DISTRICT}<br/>
      Shehia: #{shehia.SHEHIA}<br/>
    "

  selectForNameAndLevel: (name, level) ->
    "
      <option></option>
      #{
        _(GeoHierarchy.findChildrenNames(level,name)).map (name) ->
          "<option>#{name}</option>"
        .join ""
      }
    "

  currentRegion: ->
    $("#region option:selected").text()

  currentDistrict: ->
    $("#district option:selected").text()

  currentShehias: ->
    $("#shehias").val().split('\n')

  changeDistrict: =>
    $("#shehias").html _(GeoHierarchy.findChildrenNames("SHEHIA",@currentDistrict())).join("\n")
    $("#shehias-box").show()

  changeRegion: =>
    $("#district").html @selectForNameAndLevel(@currentRegion(),"DISTRICT")

  save: ->
    GeoHierarchy.update @currentRegion(), @currentDistrict(), @currentShehias()
