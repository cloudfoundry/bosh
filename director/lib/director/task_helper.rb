module Bosh::Director

  module TaskHelper

    def create_task(user, description)
      user = Models::User[:username => user]
      task = Models::Task.create(:user => user, :description => description,
                                 :state => :queued, :timestamp => Time.now)
      task_status_file = File.join(Config.base_dir, "tasks", task.id.to_s)
      FileUtils.mkdir_p(File.dirname(task_status_file))
      logger = Logger.new(task_status_file)
      logger.level= Config.logger.level
      logger.info("Enqueuing task: #{task.id}")

      task.output = task_status_file
      task.save
      task
    end

  end

end