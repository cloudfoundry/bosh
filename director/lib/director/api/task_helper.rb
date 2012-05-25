# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    module TaskHelper
      def create_task(user, type, description)
        user = Models::User[:username => user]
        task = Models::Task.create(:user => user,
                                   :type => type,
                                   :description => description,
                                   :state => :queued,
                                   :timestamp => Time.now,
                                   :checkpoint_time => Time.now)
        log_dir = File.join(Config.base_dir, "tasks", task.id.to_s)
        task_status_file = File.join(log_dir, "debug")
        FileUtils.mkdir_p(log_dir)
        logger = Logger.new(task_status_file)
        logger.level= Config.logger.level
        logger.info("Director Version : #{Bosh::Director::VERSION}")
        logger.info("Enqueuing task: #{task.id}")

        # remove old tasks
        min_task_id = task.id - Config.max_tasks
        task_files = Dir.glob(File.join(Config.base_dir, "tasks/*"))
        task_files.each do |file_path|
          begin
            task_file = File.basename(file_path)
            task_id = Integer(task_file)

            if task_id < min_task_id && task_id >= 0
              logger.info("Delete #{task_file}")
              FileUtils.rm_rf file_path
              Models::Task[task_id].destroy
            end
          rescue
            # skip over invalid task files
          end
        end

        task.output = log_dir
        task.save
        task
      end
    end
  end
end
