require 'spec_helper'

describe 'worker' do
  subject(:worker) { Bosh::Director::Worker.new(config) }
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
      'nats_server_ca_path' => '/path/to/nats/ca/cert',
      'nats_tls' => {
        'private_key_path' => '/path/to/nats/tls/private_key',
        'certificate_path' => '/path/to/nats/tls/certificate.pem'
      }
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
      sleep 0.1 # Ruby 1.9 fails without the sleep due to a race condition between rspec assertion and actually killing the process
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
      expect(event.object_name).to eq('worker_0')
      expect(event.context).to eq({})
    end
  end
end
