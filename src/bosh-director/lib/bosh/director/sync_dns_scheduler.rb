require 'db_migrator'
require 'optparse'
require 'bosh/director/config'

module Bosh::Director
  class SyncDnsScheduler
    def initialize(config, interval)
      @config = config
      @interval = interval
    end

    def prep
      ensure_migrations

      require 'bosh/director'
      Bosh::Director::App.new(@config)

      @dns_version_converger = Bosh::Director::DnsVersionConverger.new(
        Bosh::Director::AgentBroadcaster.new,
        Bosh::Director::Config.logger,
        Bosh::Director::Config.max_threads,
      )
    end

    def start!
      @thread = Thread.new do
        loop do
          sleep(@interval)
          broadcast
        end
      end

      @thread[:name] = self.class.to_s
      @thread.join
    rescue StandardError => e
      @config.sync_dns_scheduler_logger.error("Sync DNS SyncDnsScheduler exited unexpectedly: #{e.inspect} #{e.backtrace}")
      raise
    end

    def stop!
      @thread.exit
    end

    private

    def ensure_migrations
      if defined?(Bosh::Director::Models)
        raise 'Bosh::Director::Models were loaded before ensuring migrations are current. '\
              'Cowardly refusing to start sync dns scheduler.'
      end

      migrator = DBMigrator.new(@config.db)
      raise_migration_error unless migrator.finished?
    end

    def raise_migration_error
      @config.sync_dns_scheduler_logger.error(
        "Migrations not current during sync dns scheduler start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts.",
      )
      raise "Migrations not current during sync dns scheduler start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries"
    end

    def broadcast
      @dns_version_converger.update_instances_based_on_strategy
    end
  end
end
