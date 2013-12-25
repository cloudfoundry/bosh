# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh/director/api/task_remover'

module Bosh::Director
  module Api
    class TaskHelper
      def create_task(username, type, description)
        user = Models::User[:username => username]
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
        logger.level = Config.logger.level
        logger.info("Director Version : #{Bosh::Director::VERSION}")
        logger.info("Enqueuing task: #{task.id}")

        # remove old tasks
        TaskRemover.new(Config.max_tasks, logger).remove

        task.output = log_dir
        task.save
        task
      end
    end
  end
end
