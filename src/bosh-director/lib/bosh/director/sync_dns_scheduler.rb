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
        raise "Bosh::Director::Models loaded before ensuring migrations are current. Refusing to start #{self.class}."
      end

      begin
        DBMigrator.new(@config.db).ensure_migrated!
      rescue DBMigrator::MigrationsNotCurrentError => e
        @config.sync_dns_scheduler_logger.error("#{self.class} start failed: #{e.message}")
        raise e
      end

      require 'bosh/director'
    end

    def broadcast
      @dns_version_converger.update_instances_based_on_strategy
    end
  end
end
