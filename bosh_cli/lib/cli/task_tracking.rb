module Bosh::Cli
  module TaskTracking; end
end

require 'cli/task_tracking/task_tracker'
require 'cli/task_tracking/total_duration'
require 'cli/task_tracking/task_log_renderer'
require 'cli/task_tracking/null_task_log_renderer'
require 'cli/task_tracking/stage_progress_bar'
require 'cli/task_tracking/stage_collection'
require 'cli/task_tracking/event_log_renderer'
