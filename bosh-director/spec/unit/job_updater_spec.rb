require 'spec_helper'

describe Bosh::Director::JobUpdater do
  subject(:job_updater) { described_class.new(deployment_plan, job, job_renderer) }

  let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan') }

  let(:job) do
    instance_double('Bosh::Director::DeploymentPlan::Job', {
      name: 'job_name',
      update: update_config,
      unneeded_instances: [],
    })
  end

  let(:job_renderer) { instance_double('Bosh::Director::JobRenderer') }

  let(:update_config) do
    instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', {
      canaries: 1,
      max_in_flight: 1,
    })
  end

  describe 'update' do
    let(:instances) { [] }
    before { allow(job).to receive(:instances).and_return(instances) }

    let(:update_error) { RuntimeError.new('update failed') }

    let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
    before { allow(Bosh::Director::InstanceDeleter).to receive(:new).and_return(instance_deleter) }

    context 'when job is up to date' do
      let(:instances) { [instance_double('Bosh::Director::DeploymentPlan::Instance', changed?: false)] }

      it 'should do nothing' do
        job_updater.update

        check_event_log do |events|
          expect(events).to be_empty
        end
      end
    end

    context 'when job needs to be updated' do
      let(:canary) { instance_double('Bosh::Director::DeploymentPlan::Instance', index: 1, changed?: true) }
      let(:changed_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', index: 2, changed?: true) }
      let(:unchanged_instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance', index: 3, changed?: false)
      end

      let(:instances) { [canary, changed_instance, unchanged_instance] }

      let(:canary_updater) { instance_double('Bosh::Director::InstanceUpdater') }
      let(:changed_updater) { instance_double('Bosh::Director::InstanceUpdater') }
      let(:unchanged_updater) { instance_double('Bosh::Director::InstanceUpdater') }

      before do
        allow(Bosh::Director::InstanceUpdater).to receive(:new).
          with(canary, anything, job_renderer).and_return(canary_updater)

        allow(Bosh::Director::InstanceUpdater).to receive(:new).
          with(changed_instance, anything, job_renderer).and_return(changed_updater)

        allow(Bosh::Director::InstanceUpdater).to receive(:new).
          with(unchanged_instance, anything, job_renderer).and_return(unchanged_updater)
      end

      it 'should update changed job instances with canaries' do
        expect(canary_updater).to receive(:update).with(canary: true)
        expect(changed_updater).to receive(:update).with(no_args)
        expect(unchanged_updater).to_not receive(:update)

        job_updater.update

        check_event_log do |events|
          [
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'started'),
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'finished'),
            updating_stage_event(index: 2, total: 2, task: 'job_name/2', state: 'started'),
            updating_stage_event(index: 2, total: 2, task: 'job_name/2', state: 'finished'),
          ].each_with_index do |expected_event, index|
            expect(events[index]).to include(expected_event)
          end
        end
      end

      it 'should not continue updating changed job instances if canaries failed' do
        expect(canary_updater).to receive(:update).with(canary: true).and_raise(update_error)
        expect(changed_updater).to_not receive(:update)
        expect(unchanged_updater).to_not receive(:update)

        expect { job_updater.update }.to raise_error(update_error)

        check_event_log do |events|
          [
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'started'),
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'failed'),
          ].each_with_index do |expected_event, index|
            expect(events[index]).to include(expected_event)
          end
        end
      end

      it 'should raise an error if updating changed jobs instances failed' do
        expect(canary_updater).to receive(:update).with(canary: true)
        expect(changed_updater).to receive(:update).and_raise(update_error)
        expect(unchanged_updater).to_not receive(:update)

        expect { job_updater.update }.to raise_error(update_error)

        check_event_log do |events|
          [
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'started'),
            updating_stage_event(index: 1, total: 2, task: 'job_name/1 (canary)', state: 'finished'),
            updating_stage_event(index: 2, total: 2, task: 'job_name/2', state: 'started'),
            updating_stage_event(index: 2, total: 2, task: 'job_name/2', state: 'failed'),
          ].each_with_index do |expected_event, index|
            expect(events[index]).to include(expected_event)
          end
        end
      end
    end

    context 'when the job has unneeded instances' do
      let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      before { allow(job).to receive(:unneeded_instances).and_return([instance]) }

      it 'should delete the unneeded instances' do
        allow(Bosh::Director::Config.event_log).to receive(:begin_stage).and_call_original
        expect(Bosh::Director::Config.event_log).to receive(:begin_stage).
          with('Deleting unneeded instances', 1, ['job_name'])
        expect(instance_deleter).to receive(:delete_instances).
          with([instance], instance_of(Bosh::Director::EventLog::Stage), { max_threads: 1 })

        job_updater.update
      end
    end

    context 'when the job has no unneeded instances' do
      before { allow(job).to receive(:unneeded_instances).and_return([]) }

      it 'should not delete instances if there are not any unneeded instances' do
        expect(instance_deleter).to_not receive(:delete_instances)
        job_updater.update
      end
    end

    def updating_stage_event(options)
      {
        'stage' => 'Updating job',
        'tags' => ['job_name'],
        'index' => options[:index],
        'total' => options[:total],
        'task' => options[:task],
        'state' => options[:state]
      }
    end
  end
end
