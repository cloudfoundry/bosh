module Bosh::Cli::Command
  class Task < Base

    def track(*args)
      auth_required

      task_id = args.shift.to_i

      if task_id <= 0
        err("Task id is expected to be a positive integer")
      end

      flags = args

      if task_id.nil? || %w(last latest).include?(task_id)
        last = director.list_recent_tasks(1)
        if last.size == 0
          err("No tasks found")
        end

        task_id = last[0]["id"]
      end

      task = Bosh::Cli::DirectorTask.new(director, task_id)
      say("Task state: #{task.state}")

      cached_output = get_cached_task_output(task_id) unless flags.include?("--no-cache")

      if cached_output
        say cached_output
        return
      end

      complete_output = ""

      say("Task log:")
      begin
        state, output = task.state, task.output

        if output
          say(output)
          complete_output << output
        end

        sleep(0.5)

      end while ["queued", "processing", "cancelling"].include?(state)

      final_out = task.flush_output

      if final_out
        say(final_out)
        complete_output << final_out
      end

      status = "Task #{task_id}: state is '#{state}'"
      complete_output << "\n" << status << "\n"

      say "\n"
      say status

      save_task_output(task_id, complete_output)
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

    def get_cached_task_output(task_id)
      cache.read(task_cache_key(task_id))
    end

    def save_task_output(task_id, output)
      cache.write(task_cache_key(task_id), output)
    end

    def task_cache_key(task_id)
      "task/#{target}/#{task_id}"
    end

  end
end
