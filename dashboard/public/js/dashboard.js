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
        element.find(".body").html(data.html);
        loader.hide();
      },
      error: function(xhr, err) {
        var message = "";
        if (xhr.readyState == 4) {
          var response = eval("(" + xhr.responseText + ")");
          message = response.message;
        } else {
          message = "Error fetching data";
        }
        element.find(".body").html("<div class='error'>" + message + "</div>");
        loader.hide();
      }
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