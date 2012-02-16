# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Task < Base

    # Tracks a running task or outputs the logs from an old task.  Triggered
    # with 'bosh task <task_num>'.  Check parse_flags to see what flags can be
    # used with this.
    #
    # @param [Array] args The arguments from the command line command.
    def track(*args)
      auth_required

      task_id, log_type, no_cache, raw_output = parse_flags(args)

      err("Task id must be a positive integer") unless task_id.to_i > 0

      task = Bosh::Cli::DirectorTask.new(director, task_id, log_type)
      say("Task state: #{task.state}")

      cached_output = get_cached_task_output(task_id, log_type) unless no_cache

      if raw_output
        renderer = Bosh::Cli::TaskLogRenderer.new
      else
        renderer = Bosh::Cli::TaskLogRenderer.create_for_log_type(log_type)
        renderer.time_adjustment = director.get_time_difference
      end

      say("Task log:")

      if cached_output
        renderer.add_output(cached_output)
        # renderer.finish calls render which prints the output.
        renderer.finish(task.state)
      else
        # This calls renderer.finish which calls render and prints the output.
        fetch_print_and_save_output(task, task_id, log_type, renderer)
      end

      nl

      print_task_state_and_timing(task, task_id, renderer)
    end

    # Whether the bosh user has asked for the last (most recently run) task.
    #
    # @param [String] task_id The task id specified by the user. Could be a
    #     number as a string or it could be "last" or "latest".
    # @return [Boolean] Whether the user is asking for the most recent task.
    def asking_for_last_task?(task_id)
      task_id.nil? || ["last", "latest"].include?(task_id)
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
      elsif flags.include?("--event")
        "event"
      else
        "debug"
      end
    end

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

    # Grabs the log output for a task, prints it, then saves it to the cache.
    #
    # @param [Bosh::Cli::DirectorTask] task The director task that has all of
    # the methods for retrieving/parsing the director's task JSON.
    # @param [String] task_id The ID of the task to get logs on.
    # @param [String] log_type The type of log output.
    # @param [Bosh::Cli::TaskLogRenderer] renderer The renderer that renders the
    #     parsed task JSON.
    def fetch_print_and_save_output(task, task_id, log_type, renderer)
      complete_output = ""

      begin
        state, output = task.state, task.output

        if output
          renderer.add_output(output)
          complete_output << output
        end

        renderer.refresh
        sleep(0.5)

      end while ["queued", "processing", "cancelling"].include?(state)

      final_out = task.flush_output

      if final_out
        renderer.add_output(final_out)
        complete_output << final_out << "\n"
      end

      renderer.finish(state)
      save_task_output(task_id, log_type, complete_output)
    end

    # Prints the task state and timing information at the end of the output.
    #
    # @param [Bosh::Cli::DirectorTask] task The director task that has all of
    # the methods for retrieving/parsing the director's task JSON.
    # @param [String] task_id The ID of the task to get logs on.
    # @param [Bosh::Cli::TaskLogRenderer] renderer The renderer that renders the
    #     parsed task JSON.
    def print_task_state_and_timing(task, task_id, renderer)
      final_state = task.state
      color = {
        "done" => :green,
        "error" => :red,
      }[final_state] || :yellow
      status = "Task %s state is %s" %
          [task_id.to_s.green, final_state.colorize(color)]

      duration = renderer.duration
      if final_state == "done" && duration && duration.kind_of?(Numeric)
        status += ", started: %s, ended: %s (%s)" %
            [renderer.started_at.to_s.green, renderer.finished_at.to_s.green,
             format_time(duration).green]
      end

      say(status)
    end

    def list_running
      auth_required
      tasks = director.list_running_tasks
      err("No running tasks") if tasks.empty?
      show_tasks_table(tasks.sort_by { |t| t["id"].to_i * -1 })
      say("Total tasks running now: %d" % [ tasks.size ])
    end

    def list_recent(count = 30)
      auth_required
      tasks = director.list_recent_tasks(count)
      err("No recent tasks") if tasks.empty?
      show_tasks_table(tasks)
      say("Showing %d recent %s" % [ tasks.size,
                                     tasks.size == 1 ? "task" : "tasks" ])
    end

    def cancel(task_id)
      task = Bosh::Cli::DirectorTask.new(director, task_id)
      task.cancel
      say("Cancelling task #{task_id}")
    end

    private

    def show_tasks_table(tasks)
      return if tasks.empty?
      tasks_table = table do |t|
        t.headings = "#", "State", "Timestamp", "Description", "Result"
        tasks.map do |task|
          t << [ task["id"], task["state"], Time.at(task["timestamp"]).utc,
                 task["description"].to_s, task["result"].to_s.truncate(80) ]
        end
      end

      say("\n")
      say(tasks_table)
      say("\n")
    end

    def get_cached_task_output(task_id, log_type)
      cache.read(task_cache_key(task_id, log_type))
    end

    def save_task_output(task_id, log_type, output)
      cache.write(task_cache_key(task_id, log_type), output)
    end

    def task_cache_key(task_id, log_type)
      "task/#{target}/#{task_id}/#{log_type}"
    end

  end
end
