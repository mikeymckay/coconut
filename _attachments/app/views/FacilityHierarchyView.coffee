class FacilityHierarchyView extends Backbone.View
  el: '#content'

  render: ->
    @$el.html "
      <h1>Manage Facility Information</h1>

      <div style='float:right'>
        <div id='search-result'></div>
        Search by Facility
        <input id='search'></input>
      </div>


      Select the region and district:
      <br/>
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
      <br/>
      <div style='display:none' id='actions'>
        <button id='new-facility-button' type='button'>Create new facility</button>
        <button id='add-number-button' type='button'>Add Number</button>
      </div>
      <br/>
      <br/>
      <div style='display:none' id='new-facility'>
        New Facility Name
        <input id='facility-name'></input>
        <br/>
        <button id='save-facility' type='button'>Save New Facility</button>
      </div>

      <div style='display:none' id='update-number'>
        <h2>Facility Numbers</h2>
        <br/>
        Select Facility to Update Numbers:
          <select id='facility'>
          </select>
        <br/>
        <div style='display:none' id='number-textbox'>
          <small>
          Each phone number must be on it's own line line, for example:<br/>
          <br/>
          0755013202<br/>
          +255686628670<br/>
          +255788074705<br/>
          </small>

          <br/>
          <br/>
          <textarea style='width:100%; height:200px;' id='facility-numbers'>
          </textarea>

          <br/>
          <button id='save-numbers' type='button'>Save Numbers</button>
        </div>
      </div>

      <div id='message'></div>
    "
    $("a").button()

    $("#search").typeahead
      local: FacilityHierarchy.allFacilities()
    .on "typeahead:selected", @search

  events:
    "change #region": "changeRegion"
    "change #district": "changeDistrict"
    "change #facility": "changeFacility"
    "click #new-facility-button": "showNewFacility"
    "click #add-number-button": "showUpdateNumber"
    "click #save-facility": "saveFacility"
    "click #save-numbers": "saveNumbers"

  search: ->
    facility = $("#search").val()
    district = FacilityHierarchy.getFacility facility
    $("#search-result").html "
      Facility: #{facility}<br/>
      District: #{district}<br/>
    "

  showNewFacility: () ->
    $("#new-facility").show()
    $("#update-number").hide()

  showUpdateNumber: () ->
    $("#new-facility").hide()
    $("#update-number").show()

  selectForNameAndLevel: (name, level) ->
    "
      <option></option>
      #{
        _(GeoHierarchy.findChildrenNames(level,name)).map (name) ->
          "<option>#{name}</option>"
        .join ""
      }
    "

  shehiaSelectForNameAndLevel: (name, level) ->
    "
      <option></option>
      #{
        _(FacilityHierarchy.facilities @currentDistrict()).map (name) ->
          "<option>#{name}</option>"
        .join ""
      }
    "

  currentRegion: ->
    $("#region option:selected").text()

  currentDistrict: ->
    $("#district option:selected").text()

  currentFacility: ->
    $("#facility option:selected").text()

  currentNumbers: ->
    $("#facility-numbers").val().split("\n")


  changeRegion: =>
    $("#district").html @selectForNameAndLevel(@currentRegion(),"DISTRICT")

  changeDistrict: =>
    $("#actions").show()
    $("#facility").html @shehiaSelectForNameAndLevel(@currentDistrict(),"DISTRICT")

  changeFacility: =>
    $("#facility-numbers").html FacilityHierarchy.numbers(@currentDistrict(), @currentFacility()).join("\n")
    $("#number-textbox").show()

  saveFacility: =>
    facilityName = $("#facility-name").val()
    FacilityHierarchy.update @currentDistrict(),facilityName, [],
      success: =>
        _.delay =>
          $("#facility").html @shehiaSelectForNameAndLevel(@currentDistrict(),"DISTRICT")
          @showUpdateNumber()
          $("#facility").val(facilityName)
          $("#number-textbox").show()
        ,500

  saveNumbers: ->
    FacilityHierarchy.update @currentDistrict(), @currentFacility(), @currentNumbers()
