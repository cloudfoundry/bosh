require 'db_migrator'
require 'rufus-scheduler'
require 'prometheus/client'

module Bosh
  module Director
    class MetricsCollector
      attr_reader :resurrection_enabled

      def initialize(config)
        @config = config
        @logger = config.metrics_server_logger

        @registry = Prometheus::Client.registry
        @resurrection_enabled = Prometheus::Client::Gauge.new(
          :resurrection_enabled,
          docstring: 'Is resurrection enabled? 0 for disabled, 1 for enabled',
        )

        @registry.register(@resurrection_enabled)
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

        # TODO(JM/CH): we should call shutdown once we have updated to a newer
        # Rufus Scheduler
        # @scheduler.shutdown
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

        @logger.info('populated metrics')
      end
    end
  end
end
