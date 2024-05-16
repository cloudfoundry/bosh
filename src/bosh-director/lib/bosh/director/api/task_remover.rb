require 'date'

module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks, retention_period, deployment_retention_period)
      @max_tasks = max_tasks
      @retention_period = retention_period
      @deployment_retention_period = deployment_retention_period
    end

    def remove(type)
      tasks_removed = 0
      removal_max_tasks_candidates_dataset(type).paged_each(strategy: :filter, stream: false) do |task|
        tasks_removed += 1
        remove_task(task)
      end
      unless @retention_period == ''
        removal_retention_candidates_dataset(type).paged_each(strategy: :filter, stream: false) do |task|
          tasks_removed += 1
          remove_task(task)
        end
      end
      unless @deployment_retention_period == ''
        @deployment_retention_period.each do |d|
          removal_deployment_retention_candidates_dataset(type, d).paged_each(strategy: :filter, stream: false) do |task|
            tasks_removed += 1
            remove_task(task)
          end
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
        Bosh::Director::Config.logger.debug("TaskRemover: Sequel::NoExistingObject, attempting to remove #{task}.")
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
      retention_time = DateTime.now - @retention_period.to_i
      Bosh::Director::Models::Task.where(type: type)
                                  .where { checkpoint_time < retention_time }
                                  .exclude(state: %w[processing queued])
                                  .select(:id, :output)
    end

    def removal_deployment_retention_candidates_dataset(type, deployment_with_retention_period)
      retention_time = DateTime.now - deployment_with_retention_period['retention_period'].to_i
      Bosh::Director::Models::Task.where(type: type)
                                  .where(deployment_name: deployment_with_retention_period['deployment'])
                                  .where { checkpoint_time < retention_time }
                                  .exclude(state: %w[processing queued])
                                  .select(:id, :output)
    end
  end
end
