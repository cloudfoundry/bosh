require 'bosh/director/api/task_remover'

module Bosh::Director
  module Api
    class TaskHelper
      def create_task(username, type, description, deployment_name)
        task = Models::Task.create(:username => username,
                                   :type => type,
                                   :description => description,
                                   :state => :queued,
                                   :deployment_name => deployment_name,
                                   :timestamp => Time.now,
                                   :checkpoint_time => Time.now)
        log_dir = File.join(Config.base_dir, 'tasks', task.id.to_s)
        task_status_file = File.join(log_dir, 'debug')
        FileUtils.mkdir_p(log_dir)

        File.open(task_status_file, 'a') do |f|
          f << format_log_message("Director Version: #{Bosh::Director::VERSION}")
          f << format_log_message("Enqueuing task: #{task.id}")
        end

        # remove old tasks
        TaskRemover.new(Config.max_tasks).remove(type)

        task.output = log_dir
        task.save
        task
      end

      private

      def format_log_message(message)
        ThreadFormatter.new.call('INFO', Time.now, 'TaskHelper', message)
      end
    end
  end
end
