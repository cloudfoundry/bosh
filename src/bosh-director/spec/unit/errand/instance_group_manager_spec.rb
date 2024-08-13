require 'spec_helper'

module Bosh::Director
  describe Errand::InstanceGroupManager do
    subject { described_class.new(deployment, job, logger) }
    let(:ip_provider) { instance_double(DeploymentPlan::IpProvider) }
    let(:skip_drain) { instance_double(DeploymentPlan::SkipDrain) }
    let(:deployment) do
      instance_double(DeploymentPlan::Planner, ip_provider:,
                                               tags: ['tags'],
                                               template_blob_cache:,
                                               skip_drain:,
                                               use_short_dns_addresses?: false,
                                               use_link_dns_names?: false,
                                               link_provider_intents: [],
                                               name: 'fake-deployment',
                                               availability_zones: [])
    end
    let(:template_blob_cache) { instance_double(Core::Templates::TemplateBlobCache) }
    let(:missing_plans) { [instance_double(DeploymentPlan::InstancePlan)] }
    let(:job) do
      instance_double(DeploymentPlan::InstanceGroup,
                      name: 'job_name',
                      instance_plans_with_missing_vms: missing_plans)
    end
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    let(:instance1) { instance_double(DeploymentPlan::Instance, model: instance1_model) }
    let(:instance2) { instance_double(DeploymentPlan::Instance, model: instance2_model) }
    let(:vm1) { instance_double(DeploymentPlan::Vm, clean: nil) }
    let(:vm_creator) do
      instance_double(VmCreator)
    end

    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
    let(:task_writer) { TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { EventLog::Log.new(task_writer) }

    let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:instance_plan1) do
      DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil, variables_interpolator:)
    end
    let(:instance_plan2) do
      DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: nil, variables_interpolator:)
    end

    let(:dns_encoder) { instance_double(DnsEncoder) }
    let(:local_dns_manager) { instance_double(LocalDnsManager, update_dns_record_for_instance: nil) }

    before do
      fake_app
      allow(LocalDnsEncoderManager)
        .to receive(:create_dns_encoder)
        .with(false, false)
        .and_return(dns_encoder)
      allow(VmCreator).to receive(:new)
        .with(
          an_instance_of(Logging::Logger),
          template_blob_cache,
          dns_encoder,
          an_instance_of(Bosh::Director::AgentBroadcaster),
          deployment.link_provider_intents,
        )
        .and_return vm_creator
      allow(job).to receive(:needed_instance_plans).with(no_args).and_return([instance_plan1, instance_plan2])
      allow(Config).to receive(:event_log).and_return(event_log)

      allow(LocalDnsManager).to receive(:create).with(Config.root_domain, logger).and_return(local_dns_manager)
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
        instance_group_updater = instance_double(InstanceGroupUpdater)
        expect(InstanceGroupUpdater).to receive(:new).with(
          ip_provider:,
          instance_group: job,
          disk_manager: an_instance_of(DiskManager),
          template_blob_cache:,
          dns_encoder:,
          link_provider_intents: deployment.link_provider_intents,
        ).and_return(instance_group_updater)
        expect(instance_group_updater).to receive(:update).with(no_args)

        subject.update_instances
      end
    end

    describe '#delete_vms' do
      let(:manifest) { Bosh::Spec::Deployments.simple_manifest_with_instance_groups }
      let(:deployment_model) { FactoryBot.create(:models_deployment, manifest: YAML.dump(manifest)) }

      let(:instance1_model) do
        is = Models::Instance.make(deployment: deployment_model, job: 'foo-job', uuid: 'instance_id1', index: 0, ignore: true)
        vm1_model = Models::Vm.make(cid: 'vm_cid1', instance_id: is.id)
        is.active_vm = vm1_model
        is
      end
      let(:instance2_model) do
        Models::Instance.make(deployment: deployment_model, job: 'foo-job', uuid: 'instance_id2', index: 1, ignore: true,
                              state: 'detached')
      end

      let(:instance_plan1) do
        DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance1,
                                         variables_interpolator:)
      end
      let(:instance_plan2) do
        DeploymentPlan::InstancePlan.new(existing_instance: instance2_model, desired_instance: nil, instance: instance2,
                                         variables_interpolator:)
      end

      let(:unmount_step) { instance_double(DeploymentPlan::Steps::UnmountInstanceDisksStep) }
      let(:vm_deleter) { VmDeleter.new(logger, false, false) }

      context 'when there are instance plans' do
        before do
          allow(DeploymentPlan::Steps::UnmountInstanceDisksStep).to receive(:new).with(instance1_model).and_return(unmount_step)
          allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(Api::EventManager.new({}))
          allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
          allow(Config).to receive_message_chain(:current_job, :task_id).and_return('task-1', 'task-2')

          allow(VmDeleter).to receive(:new).and_return(vm_deleter)
        end

        it 'deletes vms for all obsolete plans' do
          expect(vm_deleter).to receive(:delete_for_instance).with(instance1_model)
          expect(vm_deleter).to receive(:delete_for_instance).with(instance2_model)
          expect(unmount_step).to receive(:perform)

          expect(local_dns_manager).to receive(:delete_dns_for_instance).with(instance1_model)
          expect(local_dns_manager).to receive(:delete_dns_for_instance).with(instance2_model)

          subject.delete_vms
        end
      end

      context 'when there are no instance plans' do
        before do
          allow(job).to receive(:needed_instance_plans).with(no_args).and_return([])
        end

        it 'does not try to delete vms' do
          expect(vm_deleter).to_not receive(:delete_for_instance)
          expect(unmount_step).to_not receive(:perform)
          expect(logger).to receive(:info).with('No errand vms to delete')

          subject.delete_vms
        end
      end
    end
  end
end
