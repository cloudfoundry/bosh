module Bosh::Cli::Command
  class Task < Base

    INCLUDE_ALL = "Include all task types (ssh, logs, vms, etc)"

    # bosh task
    usage  "task"
    desc   "Show task status and start tracking its output"
    option "--event", "Track event log"
    option "--cpi", "Track CPI log"
    option "--debug", "Track debug log"
    option "--result", "Track result log"
    option "--raw", "Show raw log"
    option "--no-filter", INCLUDE_ALL
    def track(task_id = nil)
      auth_required
      show_current_state
      use_filter = !options.key?(:no_filter)
      raw_output = options[:raw]

      log_type = "event"
      n_types = 0
      if options[:cpi]
        log_type = "cpi"
        n_types += 1
      end

      if options[:debug]
        log_type = "debug"
        n_types += 1
      end

      if options[:event]
        log_type = "event"
        n_types += 1
      end

      if options[:result]
        log_type = "result"
        raw_output = true
        n_types += 1
      end

      if n_types > 1
        err("Cannot track more than one log type")
      end

      track_options = {
        :log_type => log_type,
        :raw_output => raw_output
      }

      if task_id.nil? || %w(last latest).include?(task_id)
        task_id = get_last_task_id(get_verbose_level(use_filter))
      end

      if task_id.to_i <= 0
        err("Task id must be a positive integer")
      end

      tracker = Bosh::Cli::TaskTracking::TaskTracker.new(director, task_id, track_options)
      tracker.track
    end

    # bosh tasks
    usage "tasks"
    desc "Show running tasks"
    option "--no-filter", INCLUDE_ALL
    def list_running
      auth_required
      show_current_state
      use_filter = !options.key?(:no_filter)
      tasks = director.list_running_tasks(get_verbose_level(use_filter))
      err("No running tasks") if tasks.empty?
      show_tasks_table(tasks.sort_by { |t| t["id"].to_i * -1 })
      say("Total tasks running now: %d" % [tasks.size])
    end

    # bosh tasks recent
    usage "tasks recent"
    desc "Show <number> recent tasks"
    option "--no-filter", INCLUDE_ALL
    def list_recent(count = 30)
      auth_required
      show_current_state
      use_filter = !options.key?(:no_filter)
      tasks = director.list_recent_tasks(count, get_verbose_level(use_filter))
      err("No recent tasks") if tasks.empty?
      show_tasks_table(tasks)
      say("Showing #{tasks.size} recent #{tasks.size == 1 ? "task" : "tasks"}")
    end

    # bosh cancel task
    usage "cancel task"
    desc "Cancel task once it reaches the next checkpoint"
    def cancel(task_id)
      auth_required
      show_current_state
      task = Bosh::Cli::DirectorTask.new(director, task_id)
      task.cancel
      say("Task #{task_id} is getting canceled")
    end

    private

    # Returns the task id of the most recently run task.
    # @return [String] The task id of the most recently run task.
    def get_last_task_id(verbose = 1)
      last = director.list_recent_tasks(1, verbose)
      if last.empty?
        err("No tasks found")
      end

      last[0]["id"]
    end

    def show_tasks_table(tasks)
      return if tasks.empty?
      tasks_table = table do |t|
        t.headings = "#", "State", "Timestamp", "User", "Description", "Result"
        tasks.map do |task|
          t << [task["id"], task["state"], Time.at(task["timestamp"]).utc, task["user"],
                task["description"].to_s, task["result"].to_s.truncate(80)]
        end
      end

      say("\n")
      say(tasks_table)
      say("\n")
    end

    # Returns the verbose level for the given no_filter flag
    # @param [Boolean] use_filter Is filtering performed?
    # @return [Number] director verbose level
    def get_verbose_level(use_filter)
      use_filter ? 1 : 2
    end
  end
end
