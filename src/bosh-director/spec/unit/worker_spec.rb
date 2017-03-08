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
      'config_server' => {
        'enabled' => false
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
end
