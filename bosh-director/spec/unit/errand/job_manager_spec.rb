require 'spec_helper'

module Bosh::Director
  describe Errand::JobManager do
    subject { described_class.new(deployment, job, blobstore, event_log) }
    let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'job_name') }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

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
        expect(JobRenderer).to receive(:new).with(job).and_return(job_renderer)
        expect(job_renderer).to receive(:render_job_instances).with(blobstore)

        job_updater = instance_double('Bosh::Director::JobUpdater')
        expect(JobUpdater).to receive(:new).with(deployment, job).and_return(job_updater)
        expect(job_updater).to receive(:update).with(no_args)

        subject.update_instances
      end
    end

    describe '#delete' do
      before { allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance1_model) }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance2_model) }

      let(:instance1_model) { instance_double('Bosh::Director::Models::Instance') }
      let(:instance2_model) { instance_double('Bosh::Director::Models::Instance') }

      it 'deletes all job instances' do
        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        allow(event_log).to receive(:begin_stage).
          with('Deleting instances', 2, ['job_name']).
          and_return(event_log_stage)

        instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
        expect(InstanceDeleter).to receive(:new).with(deployment).and_return(instance_deleter)
        expect(instance_deleter).to receive(:delete_instances).
          with([instance1_model, instance2_model], event_log_stage)

        subject.delete_instances
      end
    end
  end
end
