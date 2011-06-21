module Bosh::Director

  module TaskHelper

    def create_task(user, description)
      user = Models::User[:username => user]
      task = Models::Task.create(:user => user, :description => description,
                                 :state => :queued, :timestamp => Time.now)
      task_status_file = File.join(Config.base_dir, "tasks", task.id.to_s, task.id.to_s)
      FileUtils.mkdir_p(File.dirname(task_status_file))
      logger = Logger.new(task_status_file)
      logger.level= Config.logger.level
      logger.info("Enqueuing task: #{task.id}")

      # remove old tasks
      Dir.chdir(File.join(Config.base_dir, "tasks")) do
        min_task_id = task.id - Config.max_tasks
        task_files = Dir.glob("*")
        task_files.each do |task_file|
          begin
            task_id = Integer(task_file)
            if (task_id < min_task_id && task_id >= 0)
              logger.info("Delete #{task_file}")
              FileUtils.rm_rf task_file
              Models::Task[task_id].destroy
            end
          rescue
            # skip over invalid task files
          end
        end
      end

      task.output = task_status_file
      task.save
      task
    end
  end
end
