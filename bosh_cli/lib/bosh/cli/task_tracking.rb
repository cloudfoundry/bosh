module Bosh::Cli
  module TaskTracking; end
end

require 'bosh/cli/task_tracking/task_tracker'
require 'bosh/cli/task_tracking/total_duration'
require 'bosh/cli/task_tracking/smart_whitespace_printer'
require 'bosh/cli/task_tracking/task_log_renderer'
require 'bosh/cli/task_tracking/null_task_log_renderer'
require 'bosh/cli/task_tracking/stage_collection'
require 'bosh/cli/task_tracking/stage_collection_presenter'
require 'bosh/cli/task_tracking/event_log_renderer'
