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
        'config_server' => {
          'enabled' => false
        },
        'uuid' => 'fake-director-uuid',
      }
    end
    let(:config) { Bosh::Director::Config.load_hash(config_hash) }

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

        expect(djworker.name).to match(/^worker_0-([a-f0-9\-]{36})$/)
      end

      describe 'when explicitly set' do
        subject(:worker) { described_class.new(config, '99') }

        it 'should use it for worker name prefix' do
          worker.prep

          expect(djworker.name).to match(/^worker_99-([a-f0-9\-]{36})$/)
        end
      end
    end
  end
end
