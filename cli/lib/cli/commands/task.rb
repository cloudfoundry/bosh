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

  end
end
