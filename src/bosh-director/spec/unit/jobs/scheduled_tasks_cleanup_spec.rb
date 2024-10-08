require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledTasksCleanup do
    subject { described_class.new({}) }

    let(:task_remover) { double(Bosh::Director::Api::TaskRemover) }

    before do
      allow(Config).to receive(:max_tasks).and_return(2)
      allow(Bosh::Director::Api::TaskRemover).to receive(:new).and_return(task_remover)
    end

    describe '#initialize' do
      it 'has default values for the arguments' do
        expect { described_class.new }.to_not raise_error
      end
    end

    context 'orphaned tasks exists' do
      let(:five_minutes_ago) { 5.minutes.ago }
      let!(:delayed_jobs) do
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 4, {})
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 8, {})
      end
      let!(:tasks) do
        FactoryBot.create(:models_task, id: 4, type: 'vms', state: 'processing')
        FactoryBot.create(:models_task, id: 8, type: 'deployment', state: 'processing')
        FactoryBot.create(:models_task, id: 9, timestamp: five_minutes_ago, type: 'deployment', state: 'queued')
        FactoryBot.create(:models_task, id: 10, timestamp: DateTime.now.to_time, type: 'deployment', state: 'queued')
        FactoryBot.create(:models_task, id: 11, timestamp: five_minutes_ago, type: 'snapshot_deployment', state: 'done')
        FactoryBot.create(:models_task, id: 12, timestamp: DateTime.now.to_time, type: 'update_stemcell', state: 'done')
        FactoryBot.create(:models_task, id: 13, timestamp: five_minutes_ago, type: 'deployment', state: 'queued')
      end

      describe '#perform' do
        it 'should mark orphaned tasks as errored and not clean them up instantly' do
          expect(task_remover).to receive(:remove).with('snapshot_deployment').and_return(1)
          expect(task_remover).to receive(:remove).with('update_stemcell').and_return(1)

          output = subject.perform
          expect(output).to include("Deleted tasks and logs for\n")
          expect(output).to include("1 task(s) of type 'snapshot_deployment'\n")
          expect(output).to include("1 task(s) of type 'update_stemcell'\n")
          expect(output).to match(/Marked orphaned tasks with ids: \[(9, 13|13, 9)\] as errored. They do not have a worker job backing them/)

          Models::Task.select.where(id: [9, 13]).each do |task|
            expect(task.state).to eq('error')
          end
          # Will not be marked as errored. It's not older than 5 minutes.
          expect(Models::Task.find(id: 10).state).to eq('queued')
        end
      end
    end
    context 'there are task counts beyond max_tasks' do
      let!(:delayed_jobs) do
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 4, {})
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 8, {})
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 9, {})
        Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 10, {})
      end
      let!(:tasks) do
        FactoryBot.create(:models_task, id: 1, type: 'vms', state: 'done')
        FactoryBot.create(:models_task, id: 2, type: 'vms', state: 'done')
        FactoryBot.create(:models_task, id: 3, type: 'vms', state: 'done')
        FactoryBot.create(:models_task, id: 4, type: 'vms', state: 'processing')
        FactoryBot.create(:models_task, id: 5, type: 'deployment', state: 'done')
        FactoryBot.create(:models_task, id: 6, type: 'deployment', state: 'done')
        FactoryBot.create(:models_task, id: 7, type: 'deployment', state: 'done')
        FactoryBot.create(:models_task, id: 8, type: 'deployment', state: 'processing')
        FactoryBot.create(:models_task, id: 9, type: 'deployment', state: 'queued')
        FactoryBot.create(:models_task, id: 10, type: 'deployment', state: 'queued')
        FactoryBot.create(:models_task, id: 11, type: 'snapshot_deployment', state: 'done')
        FactoryBot.create(:models_task, id: 12, type: 'update_stemcell', state: 'done')
      end

      describe '.schedule_message' do
        it 'outputs a message' do
          expect(described_class.schedule_message).to eq('clean up tasks')
        end
      end

      describe '.job_type' do
        it 'returns the job type' do
          expect(described_class.job_type).to eq(:scheduled_task_cleanup)
        end
      end

      describe '#perform' do
        it 'should delete completed tasks with task remover' do
          expect(task_remover).to receive(:remove).with('deployment').and_return(1)
          expect(task_remover).to receive(:remove).with('snapshot_deployment').and_return(2)
          expect(task_remover).to receive(:remove).with('update_stemcell').and_return(3)
          expect(task_remover).to receive(:remove).with('vms').and_return(4)
          expect(subject.perform).to eq(
            "Deleted tasks and logs for\n" \
            "1 task(s) of type 'deployment'\n" \
            "2 task(s) of type 'snapshot_deployment'\n" \
            "3 task(s) of type 'update_stemcell'\n" \
            "4 task(s) of type 'vms'\n",
          )
        end
      end
    end
  end
end
