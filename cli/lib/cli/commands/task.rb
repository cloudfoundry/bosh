# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Task < Base

    # Tracks a running task or outputs the logs from an old task.  Triggered
    # with 'bosh task <task_num>'. Check parse_flags to see what flags can be
    # used with this.
    #
    # @param [Array] args The arguments from the command line command.
    def track(*args)
      auth_required

      task_id, log_type, no_cache, raw_output = parse_flags(args)

      track_options = {
        :log_type => log_type,
        :use_cache => no_cache ? false : true,
        :raw_output => raw_output
      }

      if task_id.to_i <= 0
        err("Task id must be a positive integer")
      end

      tracker = Bosh::Cli::TaskTracker.new(director, task_id, track_options)
      tracker.track
    end

    def list_running
      auth_required
      tasks = director.list_running_tasks
      err("No running tasks") if tasks.empty?
      show_tasks_table(tasks.sort_by { |t| t["id"].to_i * -1 })
      say("Total tasks running now: %d" % [tasks.size])
    end

    def list_recent(count = 30)
      auth_required
      tasks = director.list_recent_tasks(count)
      err("No recent tasks") if tasks.empty?
      show_tasks_table(tasks)
      say("Showing %d recent %s" % [tasks.size,
                                    tasks.size == 1 ? "task" : "tasks"])
    end

    def cancel(task_id)
      auth_required
      task = Bosh::Cli::DirectorTask.new(director, task_id)
      task.cancel
      say("Cancelling task #{task_id}")
    end

    private

    # Parses the command line args to see what options have been specified.
    #
    # @param [Array] flags The args that were passed in from the command line.
    # @return [String, String, Boolean, Boolean] The task id, the type of log
    #     output, whether to use cache or not, whether to output the raw log.
    def parse_flags(flags)
      task_id = flags.shift
      task_id = get_last_task_id if asking_for_last_task?(task_id)

      log_type = get_log_type(flags)
      no_cache = flags.include?("--no-cache")
      raw_output = flags.include?("--raw")

      [task_id, log_type, no_cache, raw_output]
    end

    # Whether the bosh user has asked for the last (most recently run) task.
    #
    # @param [String] task_id The task id specified by the user. Could be a
    #     number as a string or it could be "last" or "latest".
    # @return [Boolean] Whether the user is asking for the most recent task.
    def asking_for_last_task?(task_id)
      task_id.nil? || %w(last latest).include?(task_id)
    end

    # Returns the task id of the most recently run task.
    #
    # @return [String] The task id of the most recently run task.
    def get_last_task_id
      last = director.list_recent_tasks(1)
      if last.size == 0
        err("No tasks found")
      end

      last[0]["id"]
    end

    # Returns what type of log output the user is asking for.
    #
    # @param [Array] flags The args that were passed in from the command line.
    # @return [String] The type of log output the user is asking for.
    def get_log_type(flags)
      if flags.include?("--soap")
        "soap"
      elsif flags.include?("--debug")
        "debug"
      else
        "event"
      end
    end

    def show_tasks_table(tasks)
      return if tasks.empty?
      tasks_table = table do |t|
        t.headings = "#", "State", "Timestamp", "Description", "Result"
        tasks.map do |task|
          t << [task["id"], task["state"], Time.at(task["timestamp"]).utc,
                task["description"].to_s, task["result"].to_s.truncate(80)]
        end
      end

      say("\n")
      say(tasks_table)
      say("\n")
    end
  end
end
