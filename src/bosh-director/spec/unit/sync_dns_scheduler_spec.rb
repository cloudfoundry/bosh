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
  describe 'sync_dns_scheduler' do
    subject(:sync_dns_scheduler) { SyncDnsScheduler.new(config, 0.01) }
    let(:config_hash) do
      SpecHelper.spec_get_director_config
    end

    let(:config) { Config.load_hash(config_hash) }
    let(:dns_version_converger) { double(DnsVersionConverger) }

    before do
      Bosh::Director.send(:remove_const, :Models)
    end

    after do
      require 'bosh/director'
    end

    describe 'migrations' do
      let(:migrator) { instance_double(DBMigrator, current?: true) }
      before do
        allow(config).to receive(:db).and_return(double(:config_db))
        allow(DBMigrator).to receive(:new).with(config.db, :director).and_return(migrator)
      end

      it 'starts up immediately if migrations have finished' do
        allow(migrator).to receive(:finished?).and_return(true)
        expect(sync_dns_scheduler).to receive(:ensure_migrations)
        expect { sync_dns_scheduler.prep }.not_to raise_error
      end

      it 'raises error if migrations never finish' do
        logger = double(Logging::Logger)
        allow(config).to receive(:sync_dns_scheduler_logger).and_return(logger.tap { |l| allow(l).to receive(:error) })
        allow(migrator).to receive(:finished?).and_return(false)

        expect(logger).to receive(:error).with(
          /Migrations not current during sync dns scheduler start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts./,
        )
        expect do
          sync_dns_scheduler.prep
        end .to raise_error(
          /Migrations not current during sync dns scheduler start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries/,
        )
      end
    end
  end
end
