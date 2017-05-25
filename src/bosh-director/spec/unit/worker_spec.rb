require 'spec_helper'

module Bosh::Director
  describe Worker do
    subject(:worker) { described_class.new(config) }

    let(:config_hash) do
      {
        'dir' => '/tmp/boshdir ',
        'db' => {
          'adapter' => 'sqlite'
        },
        'verify_multidigest_path' => '/some/path',
        'blobstore' => {
          'provider' => 's3cli',
          'options' => {
            's3cli_path' => true
          }
        },
        'record_events' => true,
        'config_server' => {
          'enabled' => false
        },
        'uuid' => 'fake-director-uuid',
      }
    end
    let(:config) { Bosh::Director::Config.load_hash(config_hash) }
    before { allow(SecureRandom).to receive(:uuid).and_return('fake-uuid') }

    describe 'when workers is sent USR1' do
      let(:queues) { worker.queues }
      before { allow(Socket).to receive(:gethostname).and_return(nil) }

      it 'should not pick up new tasks' do
        ENV['QUEUE']='normal'
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
        ENV['QUEUE']='normal'
        worker.prep
        expect(worker.queues).to eq(['normal', 'local.hostname'])
      end

      it 'should not have new queue in case of urgent' do
        ENV['QUEUE']='urgent'
        worker.prep
        expect(worker.queues).to eq(['urgent'])
      end
    end

    describe 'worker index' do
      let(:djworker) { Delayed::Worker.new }
      before { allow(Delayed::Worker).to receive(:new).and_return(djworker) }

      it 'should use a default name prefix' do
        worker.prep

        expect(djworker.name).to match(/^worker_0-fake-uuid$/)
      end

      describe 'when explicitly set' do
        subject(:worker) { described_class.new(config, '99') }

        it 'should use it for worker name prefix' do
          worker.prep

          expect(djworker.name).to match(/^worker_99-fake-uuid$/)
        end
      end
    end

    context 'bosh events' do
      let(:djworker) { Delayed::Worker.new }
      before { allow(Delayed::Worker).to receive(:new).and_return(djworker) }

      it 'should record a start event' do
        worker.prep

        expect(djworker).to receive(:start)

        worker.start

        event = Bosh::Director::Models::Event.first
        expect(event.user).to eq('_director')
        expect(event.action).to eq('start')
        expect(event.object_type).to eq('worker')
        expect(event.object_name).to eq('worker_0-fake-uuid')
        expect(event.context).to eq({})
      end
    end
  end
end
