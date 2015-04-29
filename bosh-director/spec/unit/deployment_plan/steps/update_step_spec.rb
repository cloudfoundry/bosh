require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  describe DeploymentPlan::Steps::UpdateStep do
    subject { DeploymentPlan::Steps::UpdateStep.new(base_job, event_log, resource_pools, deployment_plan, multi_job_updater, cloud, blobstore) }
    let(:base_job) { Jobs::BaseJob.new }
    let(:event_log) { Bosh::Director::Config.event_log }
    let(:resource_pools) { instance_double('Bosh::Director::DeploymentPlan::ResourcePools', update: nil, refill: nil) }
    let(:deployment_plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner',
        update_stemcell_references!: nil,
        persist_updates!: nil,
        jobs_starting_on_deploy: []
      )
    end
    let(:cloud) { instance_double('Bosh::Cloud', delete_vm: nil) }
    let(:blobstore) { instance_double('Bosh::Blobstore') }
    let(:manifest) { ManifestHelper.default_legacy_manifest }
    let(:releases) { [] }
    let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }

    before do
      allow(base_job).to receive(:logger).and_return(logger)
      allow(base_job).to receive(:track_and_log).and_yield
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
    end

    describe '#perform' do
      let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance1, instance2]) }
      let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance3]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance3) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      def it_deletes_unneeded_vms
        vm_model = Models::Vm.make(:cid => 'vm-cid')
        allow(deployment_plan).to receive(:unneeded_vms).and_return([vm_model])

        expect(event_log).to receive(:begin_stage).with('Deleting unneeded VMs', 1)
        expect(cloud).to receive(:delete_vm).with('vm-cid')
      end

      def it_deletes_unneeded_instances
        instance = Models::Instance.make
        allow(deployment_plan).to receive(:unneeded_instances).and_return([instance])

        instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
        expect(InstanceDeleter).to receive(:new)
                                     .with(deployment_plan)
                                     .and_return(instance_deleter)

        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        expect(event_log).to receive(:begin_stage)
                               .with('Deleting unneeded instances', 1)
                               .and_return(event_log_stage)

        expect(instance_deleter).to receive(:delete_instances)
                                      .with([instance], event_log_stage)
      end

      def it_binds_instance_vms
        binder = instance_double('Bosh::Director::DeploymentPlan::InstanceVmBinder')
        allow(DeploymentPlan::InstanceVmBinder).to receive(:new).with(event_log).and_return(binder)
        expect(binder).to receive(:bind_instance_vms).with([instance1, instance2, instance3])
      end

      def it_binds_configuration
        job_renderer = instance_double('Bosh::Director::JobRenderer')
        allow(JobRenderer).to receive(:new).with(job1, blobstore).and_return(job_renderer)
        allow(JobRenderer).to receive(:new).with(job2, blobstore).and_return(job_renderer)
        expect(event_log).to receive(:begin_stage).with('Preparing configuration', 1)
        expect(job_renderer).to receive(:render_job_instances).with(no_args).twice
      end

      it 'runs deployment plan update stages in the correct order' do
        allow(event_log).to receive(:track).and_yield
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).with(no_args).and_return([job1, job2])

        it_deletes_unneeded_vms.ordered
        it_deletes_unneeded_instances.ordered
        expect(resource_pools).to receive(:update).with(no_args).ordered
        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        it_binds_instance_vms.ordered
        it_binds_configuration.ordered
        expect(multi_job_updater).to receive(:run).with(base_job, deployment_plan, [job1, job2]).ordered
        expect(resource_pools).to receive(:refill).with(no_args).ordered
        expect(deployment_plan).to receive(:persist_updates!).ordered
        expect(deployment_plan).to receive(:update_stemcell_references!).ordered
        subject.perform
      end

      it 'deletes unneeded vms from database and writes to event log' do
        vm_model = Models::Vm.make(:cid => 'vm-cid')
        allow(deployment_plan).to receive(:unneeded_vms).and_return([vm_model])
        allow(deployment_plan).to receive(:unneeded_instances).and_return([])

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
          allow(deployment_plan).to receive(:unneeded_vms).and_return([double(:vm, cid: 'some-cid')])
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
