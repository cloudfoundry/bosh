require 'spec_helper'

WorkerSpecModels = Bosh::Director::Models
module Kernel
  alias worker_spec_require require

  def require(path)
    Bosh::Director.const_set(:Models, WorkerSpecModels) if path == 'bosh/director' && !defined?(Bosh::Director::Models)
    worker_spec_require(path)
  end
end

module Bosh::Director
  describe Worker do
    subject(:worker) { Worker.new(config, "worker_1") }

    let(:config) { Config.load_hash(SpecHelper.director_config_hash) }

    before do
      Bosh::Director.send(:remove_const, :Models)
    end

    after do
      require 'bosh/director'
    end

    describe 'when workers is sent USR1' do
      let(:queues) { worker.queues }

      before do
        allow(Socket).to receive(:gethostname).and_return(nil)
      end

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
      let(:delayed_job_worker) { Delayed::Worker.new }
      let(:db_migrator) { instance_double(DBMigrator) }
      let(:db) { instance_double(Sequel::Database) }
      let(:logger) { double(Logging::Logger) }

      before do
        allow(logger).to receive(:error)
        allow(logger).to receive(:info)

        allow(config).to receive(:db).and_return(db)
        allow(config).to receive(:worker_logger).and_return(logger)

        allow(DBMigrator).to receive(:new).with(config.db).and_return(db_migrator)

        allow(Delayed::Worker).to receive(:new).and_return(delayed_job_worker)
        allow(delayed_job_worker).to receive(:start)
      end

      it 'starts up immediately if migrations are current' do
        allow(db_migrator).to receive(:ensure_migrated!)

        worker.prep
        worker.start

        expect(delayed_job_worker).to have_received(:start)
      end

      it 'raises error if migrations are never current' do
        migration_error = DBMigrator::MigrationsNotCurrentError.new('FAKE MIGRATION ERROR')
        allow(db_migrator).to(receive(:ensure_migrated!)) { raise migration_error }

        expect(logger).to receive(:error).with("Bosh::Director::Worker start failed: #{migration_error}")
        expect { worker.prep }.to raise_error(migration_error)

        expect(delayed_job_worker).not_to have_received(:start)
      end
    end

    context 'bosh events' do
      let(:delayed_job_worker) { Delayed::Worker.new }
      before { allow(Delayed::Worker).to receive(:new).and_return(delayed_job_worker) }

      it 'should record a start event' do
        worker.prep

        expect(delayed_job_worker).to receive(:start)

        worker.start

        event = ::Bosh::Director::Models::Event.first
        expect(event.user).to eq('_director')
        expect(event.action).to eq('start')
        expect(event.object_type).to eq('worker')
        expect(event.object_name).to eq('worker_1')
        expect(event.context).to eq({})
      end
    end

    describe 'when worker starts' do 
      let(:delayed_job_worker) { Delayed::Worker.new }
      let(:logger) { double(Logging::Logger) }

      before do 
        allow(logger).to receive(:error)
        allow(logger).to receive(:info)
        allow(Delayed::Worker).to receive(:new).and_return(delayed_job_worker) 
        allow(delayed_job_worker).to receive(:logger).and_return(logger)
      end

      it 'starts the delayed job worker' do
        allow(delayed_job_worker).to receive(:start)

        worker.prep

        expect(delayed_job_worker).to receive(:start)

        worker.start
      end

      it 'retries in case there was an error' do 
        worker.prep

        expect(delayed_job_worker).to receive(:start).and_raise(StandardError, "some_error").exactly(11).times
        expect(logger).to receive(:error).with(/Something went wrong during worker start. .*/).exactly(11).times
        expect(logger).to receive(:error).with(/Max retries reached. .* some_error/)
        expect(worker).to receive(:sleep).with(5).and_return(0).exactly(10).times

        expect do
          worker.start
        end.to raise_exception(StandardError)
      end
    end
  end
end
