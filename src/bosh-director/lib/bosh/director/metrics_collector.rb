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
          :resurrection_enabled,
          docstring: 'Is resurrection enabled? 0 for disabled, 1 for enabled',
        )

        @queued_tasks = Prometheus::Client.registry.gauge(
          :queued_tasks,
          docstring: 'Number of currently enqued tasks',
        )

        @processing_tasks = Prometheus::Client.registry.gauge(
          :processing_tasks,
          docstring: 'Number of currently enqued tasks',
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
        @queued_tasks.set(Models::Task.where(state: 'queued').count)
        @processing_tasks.set(Models::Task.where(state: 'processing').count)

        @logger.info('populated metrics')
      end
    end
  end
end
