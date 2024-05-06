require 'date'
require 'logger'

module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks, retention_period)
      @max_tasks = max_tasks
      @retention_period = retention_period
      @logger = Logger.new('/var/vcap/sys/log/director/task_remover.log', level: Logger::DEBUG)
      @logger.info("task remover initialize retention time: #{@retention_period}")
    end

    def remove(type)
      @logger.info("remove begin retention time: #{@retention_period}")
      tasks_removed = 0
      removal_max_tasks_candidates_dataset(type).paged_each(strategy: :filter, stream: false) do |task|
        tasks_removed += 1
        remove_task(task)
      end
      @logger.info("retention time: #{@retention_period}")
      unless @retention_period == ''
        removal_retention_candidates_dataset(type).paged_each(strategy: :filter, stream: false) do |task|
          tasks_removed += 1
          remove_task(task)
        end
      end
      tasks_removed
    end

    def remove_task(task)
      FileUtils.rm_rf(task.output) if task.output

      begin
        task.destroy
      rescue Sequel::NoExistingObject
        # it's possible for multiple threads to initiate task removal
        # both could get the same results from removal_candidates_dataset,
        # but only the first would succeed at deletion; ignore failure of
        # subsequent attempts
        @logger.debug("TaskRemover: Sequel::NoExistingObject, attempting to remove #{task}.")
      end
    end

    private

    def removal_max_tasks_candidates_dataset(type)
      base_filter = Bosh::Director::Models::Task.where(type: type)
        .exclude(state: %w[processing queued])
        .select(:id, :output).order { Sequel.desc(:id) }

      starting_id = base_filter.limit(1, @max_tasks).first&.id || 0

      base_filter.where { id <= starting_id }
    end

    def removal_retention_candidates_dataset(type)
      retention_time = DateTime.now.to_time - convert_to_time_duration(@retention_period)
      Bosh::Director::Models::Task.where(type: type)
                                  .where { checkpoint_time < retention_time }
                                  .exclude(state: %w[processing queued])
                                  .select(:id, :output)
    end

    def convert_to_time_duration(string)
      multipliers = { "d" => 24*60*60, "h" => 60*60, "m" => 60, "s" => 1 }

      segments = string.scan(/(\d+)([a-z])/)

      segments.inject(0) do |total, (value, unit)|
        total + value.to_i * multipliers[unit]
      end
    end
  end
end
