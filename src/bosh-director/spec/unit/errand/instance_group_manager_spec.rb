require 'spec_helper'

module Bosh::Director
  describe Errand::InstanceGroupManager do
    subject { described_class.new(deployment, job, logger) }
    let(:ip_provider) {instance_double('Bosh::Director::DeploymentPlan::IpProvider')}
    let(:skip_drain) {instance_double('Bosh::Director::DeploymentPlan::SkipDrain')}
    let(:deployment) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
        ip_provider: ip_provider,
        tags: ['tags'],
        template_blob_cache: template_blob_cache,
        skip_drain: skip_drain,
        name: 'fake-deployment',
        availability_zones: [],
      })
    end
    let(:template_blob_cache) { instance_double('Bosh::Director::Core::Templates::TemplateBlobCache')}
    let(:missing_plans) { [instance_double('Bosh::Director::DeploymentPlan::InstancePlan')] }
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'job_name',
        instance_plans_with_missing_vms: missing_plans)
    end
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance1_model) }
    let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance2_model) }
    let(:vm1) { instance_double('Bosh::Director::DeploymentPlan::Vm', clean: nil) }
    let(:vm_creator) do
      instance_double(VmCreator)
    end

    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}

    let(:instance_plan1) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil) }
    let(:instance_plan2) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil) }

    let(:dns_encoder) { instance_double(DnsEncoder) }

    before do
      fake_app
      allow(LocalDnsEncoderManager).
        to receive(:new_encoder_with_updated_index).
        with([]).
        and_return(dns_encoder)
      allow(VmCreator).to receive(:new).
        with(
          anything,
          anything,
          anything,
          template_blob_cache,
          dns_encoder,
          anything)
        .and_return vm_creator
      allow(job).to receive(:needed_instance_plans).with(no_args).and_return([instance_plan1, instance_plan2])
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
    end

    describe '#create_missing_vms' do
      it 'delegates to the vm creator' do
        expect(vm_creator).to receive(:create_for_instance_plans).with(
          missing_plans,
          ip_provider,
          ['tags'],
        )
        subject.create_missing_vms
      end
    end

    describe '#update_instances' do
      it 'binds vms to instances, creates jobs configurations and updates dns' do
        job_updater = instance_double('Bosh::Director::JobUpdater')
        expect(JobUpdater).to receive(:new).with(
          ip_provider,
          job,
          an_instance_of(DiskManager),
          template_blob_cache,
          dns_encoder,
        ).and_return(job_updater)
        expect(job_updater).to receive(:update).with(no_args)

        subject.update_instances
      end
    end

    describe '#delete_vms' do
      let(:manifest) { Bosh::Spec::Deployments.legacy_manifest }
      let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(manifest)) }

      let(:instance1_model) do
        is = Models::Instance.make(deployment: deployment_model, job: 'foo-job', uuid: 'instance_id1', index: 0, ignore: true)
        vm1_model = Models::Vm.make(cid: 'vm_cid1', instance_id: is.id)
        is.active_vm = vm1_model
        is
      end
      let(:instance2_model) do
        Models::Instance.make(deployment: deployment_model, job: 'foo-job', uuid: 'instance_id2', index: 1, ignore: true, state: 'detached')
      end

      let(:instance_plan1) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance1) }
      let(:instance_plan2) { Bosh::Director::DeploymentPlan::InstancePlan.new(existing_instance: instance2_model, desired_instance: nil, instance: instance2) }

      let(:disk_manager) { instance_double('Bosh::Director::DiskManager')}
      let(:vm_deleter) { Bosh::Director::VmDeleter.new(logger, false, false) }

      context 'when there are instance plans' do
        before do
          allow(Bosh::Director::DiskManager).to receive(:new).and_return(disk_manager)
          allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(Api::EventManager.new({}))
          allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
          allow(Config).to receive_message_chain(:current_job, :task_id).and_return('task-1', 'task-2')

          allow(Bosh::Director::VmDeleter).to receive(:new).and_return(vm_deleter)
        end

        it 'deletes vms for all obsolete plans' do
          expect(vm_deleter).to receive(:delete_for_instance).with(instance1_model)
          expect(vm_deleter).to receive(:delete_for_instance).with(instance2_model)
          expect(disk_manager).to receive(:unmount_disk_for).with(instance_plan1)

          subject.delete_vms
        end
      end

      context 'when there are no instance plans' do
        before do
          allow(job).to receive(:needed_instance_plans).with(no_args).and_return([])
        end

        it 'does not try to delete vms' do
          expect(vm_deleter).to_not receive(:delete_for_instance)
          expect(disk_manager).to_not receive(:unmount_disk_for)
          expect(logger).to receive(:info).with('No errand vms to delete')

          subject.delete_vms
        end
      end
    end
  end
end
