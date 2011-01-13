jQuery(document).ready(function($) {
  var stemcells   = $("#stemcells");
  var releases    = $("#releases");
  var deployments = $("#deployments");

  var update_block = function(block, url, render_callback) {
    var loader = block.find(".loader");
    loader.show();

    $.getJSON(url, function(json) {
      render_callback(json);
      loader.hide();
    });
  };

  var update_stemcells = function() {
    update_block(stemcells, "/stemcells", render_stemcells);
  };

  var update_releases = function() {
    update_block(releases, "/releases", render_releases);
  };

  var update_deployments = function() {
    update_block(deployments, "/deployments", render_deployments);
  };

  var update_data = function() {
    update_deployments();
    update_releases();
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

  var render_releases = function(json) {
    var table = releases.find("table");
    table.html("");
    table.append("<tr><th class='name'>Name</th><th class='versions'>Versions</th>");

    $.each(json, function(i, release) {
      var row = "<tr " + (i%2==1 ? "class='odd'" : "") +  "><td>" + release.name + "</td><td>";
      $.each(release.versions, function(j, version) {
        row += "<span class='version'>" + version + "</span>  ";
      });
      row += "</td></tr>";
      table.append(row);
    });

    table.append("<tr><td colspan=3 class='total'> Total: " + json.length  + "</td></tr>");
  };

  var render_deployments = function(json) {
    var table = deployments.find("table");
    table.html("");
    table.append("<tr><th class='name'>Name</th>");

    $.each(json, function(i, deployment) {
      table.append("<tr " + (i%2==1 ? "class='odd'" : "") +  "><td>" + deployment.name + "</td><td>");
    });

    table.append("<tr><td colspan=3 class='total'> Total: " + json.length  + "</td></tr>");
  };

  update_data();
  setInterval(update_stemcells, 30000);
  setInterval(update_releases, 30000);
  setInterval(update_deployments, 30000);
});