require 'spec_helper'
require 'bosh/director/job_queue'

module Bosh::Director
  describe JobQueue do
    class FakeJob < Jobs::BaseJob
      def self.job_type
        :snow
      end
    end

    let(:config) { Config.load_file(asset('test-director-config.yml')) }
    let(:job_class) { FakeJob }

    describe '#enqueue' do
      it 'enqueues a resque job' do
        task_helper = instance_double('Bosh::Director::Api::TaskHelper')
        expect(Bosh::Director::Api::TaskHelper).to receive(:new).and_return(task_helper)
        task = double(id: '123')

        expect(task_helper).to receive(:create_task).with('whoami', :snow, 'busy doing something').and_return(task)
        expect(Resque).to receive(:enqueue).with(job_class, '123', 'foo', 'bar')

        retval = subject.enqueue('whoami', job_class, 'busy doing something', ['foo', 'bar'])

        expect(retval).to be(task)
      end
    end
  end
end
