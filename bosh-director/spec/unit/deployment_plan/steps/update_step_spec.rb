require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  describe DeploymentPlan::Steps::UpdateStep do
    subject { DeploymentPlan::Steps::UpdateStep.new(base_job, event_log, deployment_plan, multi_job_updater, cloud) }
    let(:base_job) { Jobs::BaseJob.new }
    let(:event_log) { Bosh::Director::Config.event_log }
    let(:ip_provider) {instance_double('Bosh::Director::DeploymentPlan::IpProvider')}
    let(:skip_drain) {instance_double('Bosh::Director::DeploymentPlan::SkipDrain')}

    let(:deployment_plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner',
        update_stemcell_references!: nil,
        persist_updates!: nil,
        jobs_starting_on_deploy: [],
        instance_plans_with_missing_vms: [],
        ip_provider: ip_provider,
        skip_drain: skip_drain,
        recreate: false
      )
    end
    let(:cloud) { instance_double('Bosh::Cloud', delete_vm: nil) }
    let(:manifest) { ManifestHelper.default_legacy_manifest }
    let(:releases) { [] }
    let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }

    before do
      allow(base_job).to receive(:logger).and_return(logger)
      allow(base_job).to receive(:track_and_log).and_yield
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
      fake_app
    end

    describe '#perform' do
      let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance1, instance2]) }
      let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance3]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance3) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      before do
        allow(deployment_plan).to receive(:unneeded_vms).and_return([])
        allow(deployment_plan).to receive(:unneeded_instances).and_return([])
      end

      def it_deletes_unneeded_vms
        vm_model = Models::Vm.make(:cid => 'vm-cid')
        allow(vm_model).to receive(:instance)
        allow(deployment_plan).to receive(:unneeded_vms).and_return([vm_model])

        expect(event_log).to receive(:begin_stage).with('Deleting unneeded VMs', 1)
        expect(cloud).to receive(:delete_vm).with('vm-cid')
      end

      def it_deletes_unneeded_instances
        existing_instance = Models::Instance.make
        allow(deployment_plan).to receive(:unneeded_instances).and_return([existing_instance])

        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        expect(event_log).to receive(:begin_stage)
                               .with('Deleting unneeded instances', 1)
                               .and_return(event_log_stage)

        instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
        expect(InstanceDeleter).to receive(:new)
                                     .and_return(instance_deleter)

        expect(instance_deleter).to receive(:delete_instance_plans) do |instance_plans, event_log, _|
          expect(instance_plans.map(&:existing_instance)).to eq([existing_instance])
          expect(event_log).to eq(event_log_stage)
        end
      end

      it 'runs deployment plan update stages in the correct order' do
        allow(event_log).to receive(:track).and_yield
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).with(no_args).and_return([job1, job2])

        it_deletes_unneeded_vms.ordered
        it_deletes_unneeded_instances.ordered
        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        expect(multi_job_updater).to receive(:run).with(base_job, deployment_plan, [job1, job2]).ordered
        expect(deployment_plan).to receive(:persist_updates!).ordered
        subject.perform
      end

      it 'deletes unneeded vms from database and writes to event log' do
        vm_model = Models::Vm.make(:cid => 'vm-cid')
        allow(deployment_plan).to receive(:unneeded_vms).and_return([vm_model])

        subject.perform

        expect(Models::Vm[vm_model.id]).to be_nil
        check_event_log do |events|
          expect(events.size).to eq(2)
          expect(events.map { |e| e['stage'] }.uniq).to eq(['Deleting unneeded VMs'])
          expect(events.map { |e| e['total'] }.uniq).to eq([1])
          expect(events.map { |e| e['task'] }.uniq).to eq(%w(vm-cid))
        end
      end

      context 'when perform fails' do
        let(:some_error) { RuntimeError.new('oops') }
        before do
          allow(deployment_plan).to receive(:unneeded_vms).and_return([instance_double(Bosh::Director::Models::Vm, cid: 'some-cid')])
          allow(cloud).to receive(:delete_vm).with('some-cid').and_raise(some_error)
        end

        it 'still updates the stemcell references' do
          expect(deployment_plan).to receive(:update_stemcell_references!)
          expect{
            subject.perform
          }.to raise_error(some_error)
        end
      end
    end
  end
end
