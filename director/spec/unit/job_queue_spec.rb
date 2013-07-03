require 'spec_helper'

describe Bosh::Director::JobQueue do

  class FakeJob < Bosh::Director::Jobs::BaseJob
    def self.job_type
      :snow
    end
  end

  let(:config) { BD::Config.load_file(asset('test-director-config.yml')) }
  let(:job_class) { FakeJob }

  describe '#enqueue' do
    it 'enqueues a resque job' do

      # this is temporary until we refactor the TaskHelper out of existence
      task = double(id: '123')
      subject.should_receive(:create_task).with('whoami', :snow, 'busy doing something').and_return(task)
      Resque.should_receive(:enqueue).with(job_class, '123', 'foo', 'bar')

      retval = subject.enqueue(job_class, 'busy doing something', 'whoami', [ 'foo', 'bar' ])
      expect(retval).to be(task)
    end
  end

end