jQuery(document).ready(function($) {
  var stemcells     = $("#stemcells");
  var releases      = $("#releases");
  var deployments   = $("#deployments");
  var running_tasks = $("#running_tasks");
  var recent_tasks  = $("#recent_tasks");

  var update_block = function(block, url) {
    var loader = block.find(".loader");
    loader.show();

    $.get(url, function(html) {
      block.find(".body").html(html);
      loader.hide();
    });
  };

  var update_stemcells = function() {
    update_block(stemcells, "/stemcells");
  };

  var update_releases = function() {
    update_block(releases, "/releases");
  };

  var update_deployments = function() {
    update_block(deployments, "/deployments");
  };

  var update_running_tasks = function() {
    update_block(running_tasks, "/running_tasks");
  };

  var update_recent_tasks = function() {
    update_block(recent_tasks, "/recent_tasks");
  };

  var update_data = function() {
    update_deployments();
    update_releases();
    update_stemcells();
    update_running_tasks();
    update_recent_tasks();
  };

  update_data();
  setInterval(update_stemcells, 30000);
  setInterval(update_releases, 30000);
  setInterval(update_deployments, 30000);
  setInterval(update_running_tasks, 5000);
  setInterval(update_recent_tasks, 10000);
});