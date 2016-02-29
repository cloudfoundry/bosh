require 'spec_helper'
require 'bosh/director/job_queue'

module Bosh::Director
  describe JobQueue do
    class FakeJob < Jobs::BaseJob
      def self.job_type
        :snow
      end
      define_method :perform do
        'foo'
      end
      @queue = :sample
    end

    let(:config) { Config.load_file(asset('test-director-config.yml')) }
    let(:job_class) { FakeJob }
    let(:db_job) {Jobs::DBJob.new(job_class, task.id,  ['foo', 'bar'])}
    let(:task) {double(id: '123')}

    describe '#enqueue' do
      it 'enqueues a job' do
        task_helper = instance_double('Bosh::Director::Api::TaskHelper')
        expect(Bosh::Director::Api::TaskHelper).to receive(:new).and_return(task_helper)

        expect(task_helper).to receive(:create_task).with('whoami', :snow, 'busy doing something', 'some_deployment').and_return(task)
        expect(Jobs::DBJob).to receive(:new).with(job_class, task.id, ['foo', 'bar']).and_return(db_job)
        expect(Delayed::Job.count).to eq(0)
        retval = subject.enqueue('whoami', job_class, 'busy doing something', ['foo', 'bar'], 'some_deployment')
        expect(retval).to be(task)
        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first[:queue]).to eq('sample')
      end
    end
  end
end
