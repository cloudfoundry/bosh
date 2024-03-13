require 'spec_helper'
require 'db_migrator'

WorkerSpecModels = Bosh::Director::Models
module Kernel
  alias worker_spec_require require
  def require(path)
    Bosh::Director.const_set(:Models, WorkerSpecModels) if path == 'bosh/director' && !defined?(Bosh::Director::Models)
    worker_spec_require(path)
  end
end

module Bosh::Director
  describe 'worker' do
    subject(:worker) { Worker.new(config, 0) }
    let(:config_hash) do
      SpecHelper.spec_get_director_config
    end

    let(:config) { Config.load_hash(config_hash) }

    before do
      Bosh::Director.send(:remove_const, :Models)
    end

    after do
      require 'bosh/director'
    end

    describe 'when workers is sent USR1' do
      let(:queues) { worker.queues }
      before { allow(Socket).to receive(:gethostname).and_return(nil) }
      it 'should not pick up new tasks' do
        ENV['QUEUE'] = 'normal'
        worker.prep
        expect(worker.queues).to eq(['normal'])
        Process.kill('USR1', Process.pid)
        expect(worker.queues).to eq(['non_existent_queue'])
      end
    end

    describe 'when deployment has director_pool' do
      let(:queues) { worker.queues }
      before { allow(Socket).to receive(:gethostname).and_return('local.hostname') }

      it 'should have new queue' do
        ENV['QUEUE'] = 'normal'
        worker.prep
        expect(worker.queues).to eq(['normal', 'local.hostname'])
      end

      it 'should not have new queue in case of urgent' do
        ENV['QUEUE'] = 'urgent'
        worker.prep
        expect(worker.queues).to eq(['urgent'])
      end
    end

    describe 'migrations' do
      let(:djworker) { Delayed::Worker.new }
      let(:migrator) { instance_double(DBMigrator, current?: true) }
      before do
        allow(Delayed::Worker).to receive(:new).and_return(djworker)
        allow(config).to receive(:db).and_return(double(:config_db))
        allow(DBMigrator).to receive(:new).with(config.db, :director).and_return(migrator)
      end

      it 'starts up immediately if migrations are current' do
        allow(migrator).to receive(:finished?).and_return(true)
        allow(djworker).to receive(:start)

        worker.prep
        worker.start

        expect(djworker).to have_received(:start)
      end

      it 'raises error if migrations are never current' do
        allow(migrator).to receive(:finished?).and_return(false)

        logger = double(Logging::Logger)
        allow(config).to receive(:worker_logger).and_return(logger.tap { |l| allow(l).to receive(:error) })
        allow(djworker).to receive(:start)

        expect(logger).to receive(:error).with(
          /Migrations not current during worker start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts./,
        )
        expect { worker.prep }.to raise_error(
          /Migrations not current after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries/,
        )
        expect(djworker).not_to have_received(:start)
      end
    end

    context 'bosh events' do
      let(:djworker) { Delayed::Worker.new }
      before { allow(Delayed::Worker).to receive(:new).and_return(djworker) }

      it 'should record a start event' do
        worker.prep

        expect(djworker).to receive(:start)

        worker.start

        event = ::Bosh::Director::Models::Event.first
        expect(event.user).to eq('_director')
        expect(event.action).to eq('start')
        expect(event.object_type).to eq('worker')
        expect(event.object_name).to eq('worker_0')
        expect(event.context).to eq({})
      end
    end
  end
end
