jQuery(document).ready(function($) {
  var stemcells     = $("#stemcells");
  var releases      = $("#releases");
  var deployments   = $("#deployments");
  var running_tasks = $("#running_tasks");
  var recent_tasks  = $("#recent_tasks");

  var update_block = function(element, url) {
    if (element.length == 0) {
      return;
    }

    var loader = element.find(".loader");
    loader.show();

    $.ajax({
      url: url,
      type: "GET",
      dataType: "json",
      success: function(data) {
        if (data.error) {
          element.find(".body").html("<div class='error'>" + data.error + "</div>");
        } else {
          element.find(".body").html(data.html);
        }
        loader.hide();
      },
      error: function(xhr, err) {
        element.find(".body").html("<div class='error'>Error fetching data</div>");
        loader.hide();
      }
    });
  };

  var update_stemcells = function() {
    update_block(stemcells, "/stemcells.json");
  };

  var update_releases = function() {
    update_block(releases, "/releases.json");
  };

  var update_deployments = function() {
    update_block(deployments, "/deployments.json");
  };

  var update_running_tasks = function() {
    update_block(running_tasks, "/running_tasks.json");
  };

  var update_recent_tasks = function() {
    update_block(recent_tasks, "/recent_tasks.json");
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