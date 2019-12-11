require 'db_migrator'
require 'rufus-scheduler'
require 'prometheus/client'

module Bosh
  module Director
    class MetricsCollector
      def initialize(config)
        @config = config
        @logger = config.metrics_server_logger

        @resurrection_enabled = Prometheus::Client.registry.gauge(
          :bosh_resurrection_enabled,
          docstring: 'Is resurrection enabled? 0 for disabled, 1 for enabled',
        )

        @tasks = Prometheus::Client.registry.gauge(
          :bosh_tasks_total,
          labels: %i[state type],
          docstring: 'Number of BOSH tasks',
        )

        @scheduler = Rufus::Scheduler.new
      end

      def prep
        ensure_migrations
        Bosh::Director::App.new(@config)
      end

      def start
        @logger.info('starting metrics collector')

        populate_metrics

        @scheduler.every '30s' do
          populate_metrics
        end
      end

      def stop
        @logger.info('stopping metrics collector')
        @scheduler.shutdown
      end

      private

      def ensure_migrations
        if defined?(Bosh::Director::Models)
          raise 'Bosh::Director::Models were loaded before ensuring migrations are current. ' \
                'Cowardly refusing to start metrics collector.'
        end

        migrator = DBMigrator.new(@config.db, :director)
        unless migrator.finished?
          @logger.error(
            "Migrations not current during metrics collector start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts.",
          )
          raise "Migrations not current after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries"
        end

        require 'bosh/director'
      end

      def populate_metrics
        @logger.info('populating metrics')

        @resurrection_enabled.set(Api::ResurrectorManager.new.pause_for_all? ? 0 : 1)

        Models::Task.group_and_count(:type).distinct.each do |task|
          @tasks.set(0, labels: { state: 'processing', type: task.type })
          @tasks.set(0, labels: { state: 'queued', type: task.type })
        end

        Models::Task.where(state: %w[processing queued]).group_and_count(:type, :state).each do |task|
          @tasks.set(task.values[:count], labels: { state: task.values[:state], type: task.values[:type] })
        end

        @logger.info('populated metrics')
      end
    end
  end
end
