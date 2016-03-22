require 'spec_helper'

describe 'worker' do
  subject(:worker) { Bosh::Director::Worker.new(config) }
  let(:config_hash) do
    {
      'dir' => '/tmp/boshdir ',
      'db' => {
        'adapter' => 'sqlite'
      },
      'blobstore' => {
        'provider' => 'simple',
        'options' => {}
      }
    }
  end
  let(:config) { Bosh::Director::Config.load_hash(config_hash) }

  describe 'when workers is sent USR1' do
    let(:queues) { worker.queues }
    it 'should not pick up new tasks' do
      ENV['QUEUE']='normal'
      worker.prep
      expect(worker.queues).to eq(['normal'])
      Process.kill('USR1', Process.pid)
      sleep 0.1 # Ruby 1.9 fails without the sleep due to a race condition between rspec assertion and actually killing the process
      expect(worker.queues).to eq(['non_existent_queue'])
    end
  end
end
