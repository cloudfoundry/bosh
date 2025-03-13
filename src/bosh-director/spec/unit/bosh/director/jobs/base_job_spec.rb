require 'spec_helper'

module Bosh::Director
  describe Jobs::BaseJob do
    let(:job_runner) { instance_double(JobRunner) }

    before do
      allow(Config).to receive(:cloud_options).and_return({})
      allow(Config).to receive(:runtime).and_return('instance' => 'name/id', 'ip' => '127.0.127.0')
      allow(Config).to receive(:task_checkpoint_interval).and_return(30)
    end

    describe '#job_type' do
      it 'should complain that the method is not implemented' do
        expect { described_class.job_type }.to raise_error(NotImplementedError)
      end
    end

    it 'should propagate the job to the job runner' do
      test_job_class = Class.new(Jobs::BaseJob) do
        define_method(:perform) {
          # empty
        }
      end

      task = FactoryBot.create(:models_task)

      expect(Bosh::Director::JobRunner).to receive(:new)
        .with(test_job_class, task.id, 'workername1').and_return(job_runner)
      expect(job_runner).to receive(:run).with('arg1', 'arg2')

      test_job_class.perform(task.id, 'workername1', 'arg1', 'arg2')
    end

    describe '#task_checkpoint' do
      subject { job.task_checkpoint }

      let(:job) { described_class.new }

      it_behaves_like 'raising an error when a task has timed out or been canceled'
    end
  end
end
