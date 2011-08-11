module Bosh::Cli::Command
  class Task < Base

    def track(*args)
      auth_required

      task_id = args.shift

      flags = args

      if task_id.nil? || %w(last latest).include?(task_id)
        last = director.list_recent_tasks(1)
        if last.size == 0
          err("No tasks found")
        end

        task_id = last[0]["id"]
      end

      if task_id.to_i <= 0
        err("Task id is expected to be a positive integer")
      end

      log_type = \
      if flags.include?("--soap")
        "soap"
      elsif flags.include?("--event")
        "event"
      else
        "debug"
      end

      task = Bosh::Cli::DirectorTask.new(director, task_id, log_type)
      say("Task state: #{task.state}")

      no_cache = flags.include?("--no-cache")
      cached_output = get_cached_task_output(task_id, log_type) unless no_cache

      if flags.include?("--raw")
        renderer = Bosh::Cli::TaskLogRenderer.new
      else
        renderer = Bosh::Cli::TaskLogRenderer.create_for_log_type(log_type)
        renderer.time_adjustment = director.get_time_difference
      end

      say("Task log:")

      if cached_output
        renderer.add_output(cached_output)
        renderer.refresh
        renderer.done
      else
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

        renderer.done
        save_task_output(task_id, log_type, complete_output)
      end

      say "Task #{task_id}: state is '#{task.state}'"
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
      say("Showing %d recent %s" % [ tasks.size, tasks.size == 1 ? "task" : "tasks" ])
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
          t << [ task["id"], task["state"], Time.at(task["timestamp"]).utc, task["description"].to_s, task["result"].to_s.truncate(80) ]
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
