module Bosh::Cli::Command
  class Task < Base

    def track(task_id)
      task = Bosh::Cli::DirectorTask.new(director, task_id)
      say("Task state: #{task.state}")

      say("Task log:")
      begin
        state, output = task.state, task.output
        say(output) if output
        sleep(1)
      end while ["queued", "processing"].include?(state)
      say(task.flush_output)
      say("Task #{task_id}: state is '#{state}'")
    end

    def list_running
      tasks = director.list_running_tasks
      err("No running tasks") if tasks.empty?
      show_tasks_table(tasks)
      say("Total tasks running now: %d" % [ tasks.size ])
    end

    def list_recent(count = 30)
      tasks = director.list_recent_tasks(count)
      err("No recent tasks") if tasks.empty?
      show_tasks_table(tasks)
      say("Showing %d recent %s" % [ tasks.size, tasks.size == 1 ? "task" : "tasks" ])
    end

    private

    def show_tasks_table(tasks)
      return if tasks.empty?
      tasks_table = table do |t|
        t.headings = "#", "State", "Timestamp", "Result"
        tasks.map do |task|
          t << [ task["id"], task["state"], Time.at(task["timestamp"]).utc, task["result"].to_s.truncate(80) ]
        end
      end

      say("\n")
      say(tasks_table)
      say("\n")
    end

  end
end
