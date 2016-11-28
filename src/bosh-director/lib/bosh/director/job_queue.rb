require 'bosh/director/api/task_remover'

module Bosh::Director

  # Abstracts the delayed jobs system.

  class JobQueue
    def enqueue(username, job_class, description, params, deployment = nil)
      task = create_task(username, job_class.job_type, description, deployment)

      Delayed::Worker.backend = :sequel
      db_job = Bosh::Director::Jobs::DBJob.new(job_class, task.id, params)
      Delayed::Job.enqueue db_job

      Api::TaskRemover.new(Config.max_tasks).remove(job_class.job_type)

      task
    end

    private

    def create_task(username, type, description, deployment)
      task = Models::Task.create_with_teams(:username => username,
        :type => type,
        :description => description,
        :state => :queued,
        :deployment_name => deployment ? deployment.name : nil,
        :timestamp => Time.now,
        :teams => deployment ? deployment.teams : nil,
        :checkpoint_time => Time.now)
      log_dir = File.join(Config.base_dir, 'tasks', task.id.to_s)
      FileUtils.rm_rf(log_dir)
      task_status_file = File.join(log_dir, 'debug')
      FileUtils.mkdir_p(log_dir)

      File.open(task_status_file, 'a') do |f|
        f << format_log_message("Director Version: #{Bosh::Director::VERSION}")
        f << format_log_message("Enqueuing task: #{task.id}")
      end

      task.output = log_dir
      task.save
      task
    end

    def format_log_message(message)
      ThreadFormatter.new.call('INFO', Time.now, 'TaskHelper', message)
    end
  end
end
