require 'spec_helper'
require 'db_migrator'
require 'bosh/director/sync_dns_scheduler'

SyncDnsSchedulerSpecModels = Bosh::Director::Models
module Kernel
  alias sync_dns_scheduler_spec_require require
  def require(path)
    Bosh::Director.const_set(:Models, SyncDnsSchedulerSpecModels) if path == 'bosh/director' && !defined?(Bosh::Director::Models)
    sync_dns_scheduler_spec_require(path)
  end
end

module Bosh::Director
  describe SyncDnsScheduler do
    subject(:sync_dns_scheduler) { SyncDnsScheduler.new(config, 0.01) }

    let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

    before do
      Bosh::Director.send(:remove_const, :Models)
    end

    after do
      require 'bosh/director'
    end

    describe '#prep' do
      let(:db_migrator) { instance_double(DBMigrator) }
      let(:db) { instance_double(Sequel::Database) }
      let(:logger) { double(Logging::Logger) }

      before do
        allow(logger).to receive(:error)

        allow(config).to receive(:db).and_return(db)
        allow(config).to receive(:sync_dns_scheduler_logger).and_return(logger)

        allow(DBMigrator).to receive(:new).with(config.db).and_return(db_migrator)
      end

      it 'starts up immediately if migrations have finished' do
        allow(Bosh::Director::App).to receive(:new)

        allow(db_migrator).to receive(:ensure_migrated!)

        expect { sync_dns_scheduler.prep }.not_to raise_error
      end

      it 'raises error if migrations never finish' do
        migration_error = DBMigrator::MigrationsNotCurrentError.new('FAKE MIGRATION ERROR')
        allow(db_migrator).to(receive(:ensure_migrated!)) { raise migration_error }

        expect(logger).to receive(:error).with("Bosh::Director::SyncDnsScheduler start failed: #{migration_error}")
        expect { sync_dns_scheduler.prep }.to raise_error(migration_error)
      end
    end
  end
end
