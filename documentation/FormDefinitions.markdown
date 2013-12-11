{
  "isApplicationDoc": true,
  "collection": "question",
  "questions": [
    {
      "label": "Facility Name",
      "type": "autocomplete from code",
      "autocomplete-options": "window.FacilityOptions = FacilityHierarchy.allFacilities()",

    },
    {
      "type": "text",
      "label": "Malaria Case ID",
    },
    {
      "label": "Shehia",
      "type": "autocomplete from code",
      "autocomplete-options": "window.ShehiaOptions = WardHierarchy.allWards()",
    },
    {
      "type": "text",
      "label": "Name",
    },
    {
      "label": "complete",
      "type": "checkbox",
    }
  ],
  "resultSummaryFields": {
    "Malaria Case ID": "on",
    "Facility Name": "on"
  },
}
{
  "isApplicationDoc": true,
  "resultSummaryFields": {
    "Facility Name": "on",
    "Shehia": "on",
    "Malaria Case ID": "on",
    "Head of Household Name": "on"
  },
  "collection": "question",
  "questions": [
    {
      "label": "Facility Name",
      "type": "autocomplete from code",
      "autocomplete-options": "window.FacilityOptions = FacilityHierarchy.allFacilities()",
    },
    {
      "label": "Malaria Case ID",
      "type": "text",
    },
    {
      "label": "Date of Positive Results",
      "type": "date",
    },
    {
      "label": "Parasite Species",
      "type": "radio",
      "radio-options": "PF,NF,Unknown,Not Applicable"
    },
    {
      "label": "Reference # in OPD Register",
      "type": "number",
    },
    {
      "label": "First Name",
      "type": "autocomplete from previous entries",
    },
    {
      "type": "autocomplete from previous entries",
      "required": "false",
    },
    {
      "label": "Last Name",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Age",
      "type": "number",
    },
    {
      "label": "Age in Months or Years",
      "type": "radio",
      "radio-options": "Years, Months,Unknown,Not Applicable"
    },
    {
      "label": "Sex",
      "type": "radio",
      "radio-options": "Male,Female,Unknown,Not Applicable"
    },
    {
      "label": "Shehia",
      "type": "autocomplete from code",
      "autocomplete-options": "window.ShehiaOptions = WardHierarchy.allWards()",
    },
    {
      "label": "Village",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Sheha/Mjumbe",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Head of Household Name",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Contact Mobile # (patient/relative)",
      "type": "text",
    },
    {
      "label": "Treatment Given",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Travelled Overnight in past month",
      "type": "radio",
    },
    {
      "label": "If YES, list ALL places travelled",
      "type": "text",
      "required": "false",
      "skip_logic": "ResultOfQuestion('TravelledOvernightinpastmonth').indexOf('No') >= 0 if ResultOfQuestion('TravelledOvernightinpastmonth')?",
    },
    {
      "label": "Comment/Remarks",
      "type": "autocomplete from previous entries",
      "required": "false",
    },
    {
      "label": "complete",
      "type": "checkbox",
    }
  ]
}
{
  "isApplicationDoc": true,
  "collection": "question",
  "questions": [

    {
      "label": "Reason for visiting household",
      "radio-options": "Index Case Household, Index Case Neighbors, Mass Screen",
      "type": "radio",
      "action_on_change": "if (ResultOfQuestion('MalariaCaseID') is null and value is 'Mass Screen') then $('[name=MalariaCaseID]').val(moment().format('YYMD') + Math.floor(Math.random()*100000))",

    },

    {
      "label": "Malaria Case ID",
      "type": "text",
    },
    {
      "label": "Head of Household Name",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Shehia",
      "type": "autocomplete from code",
      "autocomplete-options": "window.ShehiaOptions = WardHierarchy.allWards()",
    },
    {
      "label": "Village",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Sheha/Mjumbe",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Contact Mobile # (patient/relative)",
      "type": "text",
    },
    {
      "label": "Household Location",
      "required": "false",
      "type": "location",
    },
    {
      "type": "number",
    },
    {
      "label": "Number of LLIN",
      "type": "number",
    },
    {
      "label": "Number of Sleeping Places (beds/mattresses)",
      "type": "number",
    },
    {
      "label": "Number of Household Members with Fever or History of Fever Within Past Week",
      "type": "number",
    },
    {
      "label": "Number of Household Members Treated for Malaria Within Past Week",
      "type": "number",
    },
    {
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "label": "Index case: If patient is female 15-45 years of age, is she is pregant?",
      "type": "radio",
    },
    {
      "label": "Index case: Patient's current status",
      "radio-options": "Feeling Better, Feeling Unchanged, Feeling Worse, Admitted, Died ",
      "type": "radio",
    },
    {
      "label": "Index case: Patient's treatment status",
      "radio-options": "Completed, In Progress, Stopped",
      "type": "radio",
    },
    {
      "label": "Index case: Slept under LLIN last night?",
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Last date of IRS",
      "type": "date",
    },
    {
      "label": "complete",
      "type": "checkbox",
    }
  ],
  "resultSummaryFields": {
    "Head of Household Name": "on",
    "Malaria Case ID": "on"
  },
}
{
  "isApplicationDoc": true,
  "questions": [
    {
      "label": "Malaria Case ID",
      "type": "text",
    },
    {
      "label": "Head of Household Name",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "First Name",
      "type": "autocomplete from previous entries",
    },
    {
      "label": "Last Name",
      "type": "autocomplete from previous entries",
    },
    {
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Age",
      "type": "number",
    },
    {
      "label": "Age in Years or Months",
      "radio-options": "Years,Months,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Sex",
      "radio-options": "Male,Female,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Fever currently or in the last two weeks?",
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Current Body Temperature (°C)",
      "type": "number",
    },
    {
      "label": "Malaria Test Result",
      "radio-options": "PF,NPF,Mixed,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Referred to Health Facility?",
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Slept under LLIN last night?",
      "radio-options": "Yes,No,Unknown,Not Applicable",
      "type": "radio",
    },
    {
      "label": "Overnight Travel in past month?",
      "type": "radio",
    },
    {
      "label": "If yes list all places travelled",
      "type": "text",
      "required": "false",
      "skip_logic": "ResultOfQuestion('OvernightTravelinpastmonth').indexOf('No') >= 0 if ResultOfQuestion('OvernightTravelinpastmonth')?",
    },
    {
      "label": "Comments",
      "type": "autocomplete from previous entries",
      "required": "false",
    },
    {
      "label": "complete",
      "type": "checkbox",
    }
  ],
  "resultSummaryFields": {
    "Malaria Test Result": "on",
    "First Name": "on",
    "Malaria Case ID": "on",
    "Head of Household Name": "on"
  },
  "collection": "question",
}
