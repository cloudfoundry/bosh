require 'spec_helper'

module Bosh::Director
  describe Errand::JobManager do
    subject { described_class.new(deployment, job, blobstore, event_log, logger) }
    let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'job_name') }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

    describe '#prepare' do
      it 'binds unallocated vms and instance networks for given job' do
        expect(job).to receive(:bind_unallocated_vms).with(no_args)
        expect(job).to receive(:bind_instance_networks).with(no_args)

        subject.prepare
      end
    end

    describe '#update' do
      before { allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      it 'binds vms to instances, creates jobs configurations and updates dns' do
        dns_binder = instance_double('Bosh::Director::DeploymentPlan::DnsBinder')
        expect(DeploymentPlan::DnsBinder).to receive(:new).with(deployment).and_return(dns_binder)
        expect(dns_binder).to receive(:bind_deployment).with(no_args)

        vm_binder = instance_double('Bosh::Director::DeploymentPlan::InstanceVmBinder')
        expect(DeploymentPlan::InstanceVmBinder).to receive(:new).with(event_log).and_return(vm_binder)
        expect(vm_binder).to receive(:bind_instance_vms).with([instance1, instance2])

        job_renderer = instance_double('Bosh::Director::JobRenderer')
        expect(JobRenderer).to receive(:new).with(job, blobstore).and_return(job_renderer)
        expect(job_renderer).to receive(:render_job_instances).with(no_args)

        job_updater = instance_double('Bosh::Director::JobUpdater')
        expect(JobUpdater).to receive(:new).with(deployment, job, job_renderer).and_return(job_updater)
        expect(job_updater).to receive(:update).with(no_args)

        subject.update_instances
      end
    end

    describe '#delete_instances' do
      let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance1_model) }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance2_model) }

      let(:instance1_model) { instance_double('Bosh::Director::Models::Instance', vm: instance1_vm) }
      let(:instance2_model) { instance_double('Bosh::Director::Models::Instance', vm: instance2_vm) }

      let(:instance1_vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid-1') }
      let(:instance2_vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid-2') }

      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }

      let(:vm1) { instance_double('Bosh::Director::DeploymentPlan::Vm', clean_vm: nil) }
      let(:vm2) { instance_double('Bosh::Director::DeploymentPlan::Vm', clean_vm: nil) }

      before do
        allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2])

        allow(InstanceDeleter).to receive(:new).and_return(instance_deleter)
        allow(instance_deleter).to receive(:delete_instances)
        allow(event_log).to receive(:begin_stage).and_return(event_log_stage)

        allow(resource_pool).to receive(:deallocate_vm).with('fake-vm-cid-1').and_return(vm1)
        allow(resource_pool).to receive(:deallocate_vm).with('fake-vm-cid-2').and_return(vm2)
        allow(job).to receive(:resource_pool).and_return(resource_pool)
      end

      it 'creates an event log stage' do
        expect(event_log).to receive(:begin_stage).with('Deleting errand instances', 2, ['job_name'])
        subject.delete_instances
      end

      it 'deletes all job instances' do
        expect(InstanceDeleter).to receive(:new).with(deployment)
        expect(instance_deleter).to receive(:delete_instances).
          with([instance1_model, instance2_model], event_log_stage)

        subject.delete_instances
      end

      it 'deallocates vms for deleted instances' do
        expect(resource_pool).to receive(:deallocate_vm).with('fake-vm-cid-1')
        expect(resource_pool).to receive(:deallocate_vm).with('fake-vm-cid-2')
        subject.delete_instances
      end

      context 'when instances are not bound' do
        let(:instance1_model) { nil }
        let(:instance2_model) { nil }

        it 'does not create an event log stage' do
          expect(event_log).not_to receive(:begin_stage)

          subject.delete_instances
        end

        it 'does not delete instances' do
          expect(instance_deleter).not_to receive(:delete_instances)

          subject.delete_instances
        end

        it 'does not deallocate vms' do
          expect(resource_pool).not_to receive(:deallocate_vm)

          subject.delete_instances
        end
      end
    end
  end
end
