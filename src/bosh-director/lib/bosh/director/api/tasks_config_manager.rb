module Bosh::Director
  module Api
    class TasksConfigManager
      include ValidationHelper
      WORKER_DEFAULT_LIMIT = 100

      def add_to_groups(delayed_job)
        Transactor.new.retryable_transaction(Bosh::Director::Config.db) do
          configs = tasks_configs
          unless configs.empty?
            payload_object = delayed_job.send(:payload_object)
            task_id = payload_object.task_id
            tasks_configs.each do |tasks_config|
              begin
                delayed_group = tasks_config[:delayed_group]
                delayed_group.add_delayed_job(delayed_job) if tasks_config[:tasks_config].applies?(task_id)
              rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
                error_message = e.message.downcase
                raise e unless error_message.include?('unique') || error_message.include?('duplicate')
                next
              end
            end
          end
        end
      end

      def rebuild_groups
        cleanup

        raw_tasks_configs.each do |raw_tasks_config|
          Bosh::Director::Models::DelayedJobGroup.create(
            config_content: raw_tasks_config.tasks_config_text,
            limit: raw_tasks_config.rate_limit? ? raw_tasks_config.rate_limit : WORKER_DEFAULT_LIMIT,
          )
        end

        delayed_jobs = Delayed::Backend::Sequel::Job.where(::Sequel.expr(failed_at: nil)).all
        delayed_jobs.each do |delayed_job|
          add_to_groups(delayed_job)
        end
      end

      private

      def cleanup
        Models::DelayedJobGroup.dataset.delete
      end

      def raw_tasks_configs
        tasks_configs = ConfigManager.new.find(type: 'tasks', name: nil)
        parsed_configs = []
        if !tasks_configs.nil? && !tasks_configs.empty?
          content_hash = YAML.safe_load(tasks_configs[0].content)
          tasks_config_hashes = safe_property(content_hash, 'rules', class: Array, default: [])
          tasks_config_hashes.each do |tasks_config_hash|
            parsed_configs << TasksConfig.parse(tasks_config_hash)
          end
        end

        parsed_configs
      end

      def tasks_configs
        delayed_groups = Bosh::Director::Models::DelayedJobGroup.all
        parsed_configs = []

        unless delayed_groups.empty?
          delayed_groups.each do |delayed_group|
            parsed_configs << {
              delayed_group: delayed_group,
              tasks_config: TasksConfig.parse(YAML.safe_load(delayed_group.config_content)),
            }
          end
        end

        parsed_configs
      end

      class TasksConfig
        extend ValidationHelper

        attr_reader :tasks_config_hash

        def initialize(options, include_filter, exclude_filter, tasks_config_hash)
          @options = options
          @include_filter = include_filter
          @exclude_filter = exclude_filter
          @task_manager = TaskManager.new
          @tasks_config_hash = tasks_config_hash
        end

        def self.parse(tasks_config_hash)
          options = safe_property(tasks_config_hash, 'options', class: Hash, default: {})
          include_filter = Filter.parse(safe_property(tasks_config_hash, 'include', class: Hash, optional: true), :include)
          exclude_filter = Filter.parse(safe_property(tasks_config_hash, 'exclude', class: Hash, optional: true), :exclude)

          new(options, include_filter, exclude_filter, tasks_config_hash)
        end

        def rate_limit?
          @options.key?('rate_limit')
        end

        def tasks_config_text
          YAML.dump(@tasks_config_hash)
        end

        def rate_limit
          @options['rate_limit']
        end

        def applies?(task_id)
          task = @task_manager.find_task(task_id)
          @include_filter.applies?(task.deployment_name, task.teams.map(&:name)) &&
            !@exclude_filter.applies?(task.deployment_name, task.teams.map(&:name))
        end
      end

      class Filter
        extend ValidationHelper

        attr_reader :applicable_deployment_names, :applicable_teams

        def initialize(applicable_deployment_names, applicable_teams, filter_type)
          @applicable_deployment_names = applicable_deployment_names
          @applicable_teams = applicable_teams
          @filter_type = filter_type
        end

        def self.parse(filter_hash, filter_type)
          applicable_deployment_names = safe_property(filter_hash, 'deployments', class: Array, default: [])
          applicable_teams = safe_property(filter_hash, 'teams', class: Array, default: [])
          new(applicable_deployment_names, applicable_teams, filter_type)
        end

        def applies?(deployment_name, deployment_teams)
          return false if teams? && !applicable_team?(deployment_teams)

          return @applicable_deployment_names.include?(deployment_name) if deployments?

          return true if @filter_type == :include

          # @filter_type == :exclude case
          teams?
        end

        def teams?
          !@applicable_teams.nil? && !@applicable_teams.empty?
        end

        def applicable_team?(deployment_teams)
          return false if deployment_teams.nil? || deployment_teams.empty? || @applicable_teams.nil?
          !(@applicable_teams & deployment_teams).empty?
        end

        def deployments?
          !@applicable_deployment_names.nil? && !@applicable_deployment_names.empty?
        end
      end
    end
  end
end
