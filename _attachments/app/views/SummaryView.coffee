class SummaryView extends Backbone.View
  el: '#content'

  render: (result) =>
    @$el.html "
      <style>
        table#summary td{
          border: solid black 1px;
        }
        table#summary tr.even{
          background-color: #C5CAE9;
        }
        table#summary tr.odd{
          background-color: #E8EAF6;
        }

        table.results th.header, table.results td{
          font-size:150%;
        }
        .dataTables_wrapper .dataTables_length{
          display: none;
        }

        .dataTables_filter input{
          display:inline;
          width:300px;
        }

        a[role=button]{
          background-color: white;
          margin-right:5px;
          -moz-border-radius: 1em;
          -webkit-border-radius: 1em;
          border: solid gray 1px;
          font-family: Helvetica,Arial,sans-serif;
          font-weight: bold;
          color: #222;
          text-shadow: 0 1px 0 #fff;
          -webkit-background-clip: padding-box;
          -moz-background-clip: padding;
          background-clip: padding-box;
          padding: .6em 20px;
          text-overflow: ellipsis;
          overflow: hidden;
          white-space: nowrap;
          position: relative;
          zoom: 1;
        }

        a[role=button].paginate_disabled_previous, a[role=button].paginate_disabled_next{
          color:gray;
        }

        a.ui-btn{
          display: inline-block;
          width: 300px;

        }

        .dataTables_info{
          float:right;
        }

        .dataTables_paginate{
          margin-bottom:20px;
        }



      </style>
      Cases on this tablet:
      <table id='summary'>
      <thead>
      <td>Date</td>
      <td>ID</td>
      <td>Type</td>
      <td>Complete</td>
      <td>Transfer</td>
      <td>Options</td>
      </thead>
      <tbody>
      #{
        _.map result.rows, (row) ->
          console.log row
          result = "
            <tr>
              <td>#{row.key}</td>
              <td><a class='button' href='#edit/result/#{row.id}'>#{row.value[0]}</a></td>
              <td>#{row.value[1]}</td>
              <td>#{row.value[2] || "false"}</td>
              <td><small>
                <pre>
                #{
                  if row.value[3]? then JSON.stringify(row.value[3],null,2).replace(/({\n|\n}|\")/g,"") else ""
                }
                </pre></small></td>
              <td> <a class='button' style='text-decoration:none' href='#transfer/#{row.value[0]}'>Transfer</a></td>
            </tr>
          "
        .join ""
      }
      </tbody>

    "
    $('a.button').button()
    $("table").dataTable
      aaSorting: [[0,"desc"]]
      iDisplayLength: 25
#    $("table td").css("border", "solid black 1px")
    $("[role=button]").button()
    $("input").textinput()
