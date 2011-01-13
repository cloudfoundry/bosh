jQuery(document).ready(function($) {

  var stemcells = $("#stemcells");

  var update_stemcells = function() {
    var loader = stemcells.find(".loader");
    loader.show();

    $.getJSON("/stemcells", function(stemcells_json, status) {
      render_stemcells(stemcells_json);
      loader.hide();
    });
  };

  var update_data = function() {
    update_stemcells();
  };

  var render_stemcells = function(json) {
    var table = stemcells.find("table");

    table.html("");

    table.append("<tr><th class='name'>Name</th><th class='version'>Version</th><th class='cid'>CID</th></tr>");
    $.each(json, function(i, sc) {
      table.append("<tr " + (i%2==1 ? "class='odd'" : "") +  "><td>" + sc.name + "</td><td>" + sc.version + "</td><td>" + sc.cid + "</td></tr>");
    });

    table.append("<tr><td colspan=3 class='total'> Total: " + json.length  + "</td></tr>");
  };

  update_data();
  setInterval(update_stemcells, 60000);
});