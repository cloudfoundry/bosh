require 'spec_helper'

describe Bosh::Director::JobUpdater do
  subject(:job_updater) { described_class.new(deployment_plan, job) }

  describe 'update' do
    let(:deployment_plan) { double(Bosh::Director::DeploymentPlan) }
    let(:canaries) { 2 }
    let(:max_in_flight) { 1 }
    let(:update_config) { double(Bosh::Director::DeploymentPlan::UpdateConfig,
      canaries: canaries, max_in_flight: max_in_flight) }

    let(:job) { double(Bosh::Director::DeploymentPlan::Job, name: 'job_name', update: update_config, unneeded_instances: []) }

    let(:instance_1) { double(Bosh::Director::DeploymentPlan::Instance, index: 1, changed?: instance_1_changed) }
    let(:instance_1_changed) { true }
    let(:instance_2) { double(Bosh::Director::DeploymentPlan::Instance, index: 2, changed?: instance_2_changed) }
    let(:instance_2_changed) { true }
    let(:instance_3) { double(Bosh::Director::DeploymentPlan::Instance, index: 3, changed?: instance_3_changed) }
    let(:instance_3_changed) { true }
    let(:instance_4) { double(Bosh::Director::DeploymentPlan::Instance, index: 4, changed?: instance_4_changed) }
    let(:instance_4_changed) { true }
    let(:instance_5) { double(Bosh::Director::DeploymentPlan::Instance, index: 5, changed?: instance_5_changed) }
    let(:instance_5_changed) { false }

    let(:instances) { [instance_1, instance_2, instance_3, instance_4, instance_5] }
    let(:instance_updater_1) { double(Bosh::Director::InstanceUpdater, update: nil) }
    let(:instance_updater_2) { double(Bosh::Director::InstanceUpdater, update: nil) }
    let(:instance_updater_3) { double(Bosh::Director::InstanceUpdater, update: nil) }
    let(:instance_updater_4) { double(Bosh::Director::InstanceUpdater, update: nil) }
    let(:instance_updater_5) { double(Bosh::Director::InstanceUpdater, update: nil) }
    let(:update_error) { RuntimeError.new('update failed') }

    let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
    before { Bosh::Director::InstanceDeleter.stub(:new).and_return(instance_deleter) }

    before do
      job.should_receive(:instances).and_return(instances)
      Bosh::Director::InstanceUpdater.stub(:new).with(instance_1, anything).and_return(instance_updater_1)
      Bosh::Director::InstanceUpdater.stub(:new).with(instance_2, anything).and_return(instance_updater_2)
      Bosh::Director::InstanceUpdater.stub(:new).with(instance_3, anything).and_return(instance_updater_3)
      Bosh::Director::InstanceUpdater.stub(:new).with(instance_4, anything).and_return(instance_updater_4)
      Bosh::Director::InstanceUpdater.stub(:new).with(instance_5, anything).and_return(instance_updater_5)
    end

    context 'when job is up to date' do
      let(:instance_1_changed) { false }
      let(:instance_2_changed) { false }
      let(:instance_3_changed) { false }
      let(:instance_4_changed) { false }

      it 'should do nothing' do
        job_updater.update
      end
    end

    context 'when job needs to be updated' do
      it 'should update changed job instances with canaries' do
        instance_updater_1.should_receive(:update).with(:canary => true)
        instance_updater_2.should_receive(:update).with(:canary => true)
        instance_updater_3.should_receive(:update).with(no_args)
        instance_updater_4.should_receive(:update).with(no_args)
        instance_updater_5.should_not_receive(:update)

        job_updater.update

        check_event_log do |events|
          expect(events.size).to eql(8)
          expect(events.map { |e| e['stage'] }.uniq).to eql(['Updating job'])
          expect(events.map { |e| e['tags'] }.uniq).to eql([['job_name']])
          expect(events.map { |e| e['index'] }.uniq).to eql([1, 2, 3, 4])
          expect(events.map { |e| e['total'] }.uniq).to eql([4])
          expect(events.map { |e| e['task'] }.uniq).to eql(['job_name/1 (canary)', 'job_name/2 (canary)',
            'job_name/3', 'job_name/4'])
          expect(events.map { |e| e['state'] }.uniq).to eql(['started', 'finished'])
        end
      end

      it 'should not continue updating changed job instances if canaries failed' do
        instance_updater_1.should_receive(:update).with(:canary => true).and_raise(update_error)
        instance_updater_2.should_not_receive(:update)
        instance_updater_3.should_not_receive(:update)
        instance_updater_4.should_not_receive(:update)
        instance_updater_5.should_not_receive(:update)

        expect do
          job_updater.update
        end.to raise_error(update_error)

        check_event_log do |events|
          expect(events.size).to eql(2)
          expect(events.map { |e| e['stage'] }.uniq).to eql(['Updating job'])
          expect(events.map { |e| e['tags'] }.uniq).to eql([['job_name']])
          expect(events.map { |e| e['index'] }.uniq).to eql([1])
          expect(events.map { |e| e['total'] }.uniq).to eql([4])
          expect(events.map { |e| e['task'] }.uniq).to eql(['job_name/1 (canary)'])
          expect(events.map { |e| e['state'] }.uniq).to eql(['started', 'failed'])
        end
      end

      it 'should raise an error if updating changed jobs instances failed' do
        instance_updater_1.should_receive(:update).with(:canary => true)
        instance_updater_2.should_receive(:update).with(:canary => true)
        instance_updater_3.should_receive(:update).with(no_args).and_raise(update_error)
        instance_updater_4.should_not_receive(:update)
        instance_updater_5.should_not_receive(:update)

        expect do
          job_updater.update
        end.to raise_error(update_error)

        check_event_log do |events|
          expect(events.size).to eql(6)
          expect(events.map { |e| e['stage'] }.uniq).to eql(['Updating job'])
          expect(events.map { |e| e['tags'] }.uniq).to eql([['job_name']])
          expect(events.map { |e| e['index'] }.uniq).to eql([1, 2, 3])
          expect(events.map { |e| e['total'] }.uniq).to eql([4])
          expect(events.map { |e| e['task'] }.uniq).to eql(['job_name/1 (canary)', 'job_name/2 (canary)',
            'job_name/3'])
          expect(events.map { |e| e['state'] }.uniq).to eql(['started', 'finished', 'failed'])
        end
      end
    end

    context 'when the job has unneeded instances' do
      before { job.stub(:unneeded_instances).and_return([instance_1]) }

      it 'should delete the unneeded instances' do
        allow(Bosh::Director::Config.event_log).to receive(:begin_stage).and_call_original
        expect(Bosh::Director::Config.event_log).to receive(:begin_stage).with('Deleting unneeded instances', 1, ['job_name'])
        instance_deleter.should_receive(:delete_instances).
          with([instance_1], instance_of(Bosh::Director::EventLog::Stage), { max_threads: max_in_flight })

        job_updater.update
      end
    end

    context 'when the job has no unneeded instances' do
      before { job.stub(:unneeded_instances).and_return([]) }

      it 'should not delete instances if there are not any unneeded instances' do
        instance_deleter.should_not_receive(:delete_instances)
        job_updater.update
      end
    end
  end
end
