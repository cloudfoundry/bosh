require 'spec_helper'

module Bosh::Director
  describe Errand::JobManager do
    subject { described_class.new(deployment, job, cloud, logger) }
    let(:ip_provider) {instance_double('Bosh::Director::DeploymentPlan::IpProvider')}
    let(:skip_drain) {instance_double('Bosh::Director::DeploymentPlan::SkipDrain')}
    let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner', {
        ip_provider: ip_provider,
        skip_drain: skip_drain
      }) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'job_name') }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    let(:cloud) { instance_double('Bosh::Clouds') }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
    before { fake_app }

    describe '#update' do
      before { allow(job).to receive(:needed_instance_plans).with(no_args).and_return([instance_plan1, instance_plan2]) }
      let(:instance_plan1) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil) }
      let(:instance_plan2) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil) }


      it 'binds vms to instances, creates jobs configurations and updates dns' do
        job_renderer = instance_double('Bosh::Director::JobRenderer')
        expect(JobRenderer).to receive(:create).and_return(job_renderer)

        links_resolver = instance_double('Bosh::Director::DeploymentPlan::LinksResolver')
        expect(DeploymentPlan::LinksResolver).to receive(:new).with(deployment, logger).and_return(links_resolver)

        job_updater = instance_double('Bosh::Director::JobUpdater')
        expect(JobUpdater).to receive(:new).and_return(job_updater)
        expect(job_updater).to receive(:update).with(no_args)

        subject.update_instances
      end
    end

    describe '#delete_instances' do
      let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance1_model) }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance2_model) }

      let(:instance1_model) { instance_double('Bosh::Director::Models::Instance', vm_cid: 'fake-vm-cid-1') }
      let(:instance2_model) { instance_double('Bosh::Director::Models::Instance', vm_cid: 'fake-vm-cid-2') }

      let(:vm_type) { instance_double('Bosh::Director::DeploymentPlan::VmType') }
      let(:stemcell) { instance_double('Bosh::Director::DeploymentPlan::Stemcell') }

      let(:vm1) { instance_double('Bosh::Director::DeploymentPlan::Vm', clean: nil) }
      let(:vm2) { instance_double('Bosh::Director::DeploymentPlan::Vm', clean: nil) }

      let(:instance_plan1) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance1) }
      let(:instance_plan2) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance2) }

      before do
        allow(job).to receive(:needed_instance_plans).with(no_args).and_return([instance_plan1, instance_plan2])

        allow(InstanceDeleter).to receive(:new).and_return(instance_deleter)
        allow(instance_deleter).to receive(:delete_instance_plans)
        allow(Config.event_log).to receive(:begin_stage).and_return(event_log_stage)

        allow(job).to receive(:vm_type).and_return(vm_type)
        allow(job).to receive(:stemcell).and_return(stemcell)
      end

      it 'creates an event log stage' do
        expect(Config.event_log).to receive(:begin_stage).with('Deleting errand instances', 2, ['job_name'])
        subject.delete_instances
      end

      it 'deletes all job instances' do
        expect(instance_deleter).to receive(:delete_instance_plans).
          with([instance_plan1, instance_plan2], event_log_stage)

        subject.delete_instances
      end

      context 'when instances are not bound' do
        let(:instance1_model) { nil }
        let(:instance2_model) { nil }

        it 'does not create an event log stage' do
          expect(Config.event_log).not_to receive(:begin_stage)

          subject.delete_instances
        end

        it 'does not delete instances' do
          expect(instance_deleter).not_to receive(:delete_instance_plans)

          subject.delete_instances
        end
      end
    end
  end
end
