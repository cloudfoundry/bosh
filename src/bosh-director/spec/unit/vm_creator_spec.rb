require 'spec_helper'
require 'timecop'

module Bosh
  module Director
    describe VmCreator do
      subject { VmCreator.new(logger, vm_deleter, template_blob_cache, dns_encoder, agent_broadcaster) }

      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:cloud_factory) { instance_double(CloudFactory) }
      let(:vm_deleter) { VmDeleter.new(logger, false, false) }
      let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
      let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
      let(:agent_client) do
        instance_double(
          AgentClient,
          wait_until_ready: nil,
          update_settings: nil,
          apply: nil,
          get_state: nil,
        )
      end
      let(:network_settings) do
        BD::DeploymentPlan::NetworkSettings.new(
          instance_group.name,
          'deployment_name',
          { 'gateway' => 'name' },
          [reservation],
          {},
          availability_zone,
          5,
          'uuid-1',
          'bosh',
          false,
        ).to_hash
      end
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:deployment_plan) do
        instance_double(DeploymentPlan::Planner, model: deployment, name: 'deployment_name', recreate: false)
      end
      let(:availability_zone) do
        BD::DeploymentPlan::AvailabilityZone.new('az-1', {})
      end
      let(:cloud_properties) { { 'ram' => '2gb' } }
      let(:network_cloud_properties) { { 'bandwidth' => '5mbps' } }
      let(:vm_type) { DeploymentPlan::VmType.new('name' => 'fake-vm-type', 'cloud_properties' => cloud_properties) }
      let(:stemcell_model) { Models::Stemcell.make(cid: 'stemcell-id', name: 'fake-stemcell', version: '123') }
      let(:stemcell) do
        stemcell_model
        stemcell = DeploymentPlan::Stemcell.parse('name' => 'fake-stemcell', 'version' => '123')
        stemcell.add_stemcell_models
        stemcell
      end
      let(:env) { DeploymentPlan::Env.new({}) }
      let(:dns_encoder) { instance_double(DnsEncoder) }

      let(:instance) do
        instance = DeploymentPlan::Instance.create_from_instance_group(
          instance_group,
          5,
          'started',
          deployment,
          {},
          nil,
          logger,
        )
        instance.bind_existing_instance_model(instance_model)
        instance
      end
      let(:reservation) do
        subnet = BD::DeploymentPlan::DynamicNetworkSubnet.new('dns', network_cloud_properties, ['az-1'])
        network = BD::DeploymentPlan::DynamicNetwork.new('name', [subnet], logger)
        BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
      end
      let(:instance_plan) do
        desired_instance = BD::DeploymentPlan::DesiredInstance.new(instance_group, {}, nil)
        network_plan = BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
        BD::DeploymentPlan::InstancePlan.new(
          existing_instance: instance_model,
          desired_instance: desired_instance,
          instance: instance,
          network_plans: [network_plan],
        )
      end

      let(:tags) { { 'mytag' => 'foobar' } }

      let(:instance_group) do
        template_model = BD::Models::Template.make
        job = BD::DeploymentPlan::Job.new(nil, 'fake-job-name', deployment.name)
        job.bind_existing_model(template_model)

        instance_group = BD::DeploymentPlan::InstanceGroup.new(logger)
        instance_group.name = 'fake-job'
        instance_group.vm_type = vm_type
        instance_group.stemcell = stemcell
        instance_group.env = env
        instance_group.jobs << job
        instance_group.default_network = { 'gateway' => 'name' }
        instance_group.update = BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 1,
          'max_in_flight' => 1,
          'canary_watch_time' => '1000-2000',
          'update_watch_time' => '1000-2000',
        )
        instance_group.persistent_disk_collection = DeploymentPlan::PersistentDiskCollection.new(logger)
        instance_group.persistent_disk_collection.add_by_disk_size(1024)
        instance_group
      end

      let(:instance_model) do
        Models::Instance.make(
          uuid: SecureRandom.uuid,
          index: 5,
          job: 'fake-job',
          deployment: deployment,
          availability_zone: 'az1',
        )
      end
      let(:vm_model) { Models::Vm.make(cid: 'new-vm-cid', instance: instance_model, cpi: 'cpi1') }

      let(:event_manager) { Api::EventManager.new(true) }
      let(:task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }
      let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
      let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
      let(:update_job) do
        instance_double(Jobs::UpdateDeployment, username: 'user', task_id: task.id, event_manager: event_manager)
      end

      let(:global_network_resolver) { instance_double(DeploymentPlan::GlobalNetworkResolver, reserved_ranges: Set.new) }
      let(:networks) { { 'my-manual-network' => manual_network } }
      let(:manual_network_spec) do
        {
          'name' => 'my-manual-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/30',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-1',
            },
            {
              'range' => '192.168.2.0/30',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-2',
            },
            {
              'range' => '192.168.3.0/30',
              'gateway' => '192.168.3.1',
              'dns' => ['192.168.3.1', '192.168.3.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'azs' => ['az-2'],
            },
          ],
        }
      end
      let(:manual_network) do
        DeploymentPlan::ManualNetwork.parse(
          manual_network_spec,
          [
            BD::DeploymentPlan::AvailabilityZone.new('az-1', {}),
            BD::DeploymentPlan::AvailabilityZone.new('az-2', {}),
          ],
          global_network_resolver,
          logger,
        )
      end
      let(:ip_repo) { DeploymentPlan::InMemoryIpRepo.new(logger) }
      let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, networks, logger) }

      let(:spec_apply_step) { instance_double(DeploymentPlan::Steps::ApplyVmSpecStep, perform: nil) }
      let(:create_vm_step) { instance_double(DeploymentPlan::Steps::CreateVmStep, perform: nil) }
      let(:update_settings_step) { instance_double(DeploymentPlan::Steps::UpdateInstanceSettingsStep, perform: nil) }
      let(:elect_active_vm_step) { instance_double(DeploymentPlan::Steps::ElectActiveVmStep, perform: nil) }
      let!(:report) { DeploymentPlan::Stages::Report.new }

      before do
        fake_app

        allow(Config).to receive(:cloud).and_return(cloud)
        allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
        allow(JobRenderer).to receive(:render_job_instances_with_cache)
          .with([instance_plan], template_blob_cache, dns_encoder, logger)
        allow(Config).to receive(:current_job).and_return(update_job)
        allow(Config.cloud).to receive(:delete_vm)
        allow(CloudFactory).to receive(:create_with_latest_configs).and_return(cloud_factory)
        allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
        allow(cloud_factory).to receive(:get_name_for_az).with(instance_model.availability_zone).and_return('cpi1')
        allow(cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
        allow(Models::Vm).to receive(:create).and_return(vm_model)
        allow(instance_model).to receive(:managed_persistent_disk_cid).and_return('fake-disk-cid')
        allow(DeploymentPlan::Stages::Report).to receive(:new).and_return(report)

        allow(DeploymentPlan::Steps::CreateVmStep).to receive(:new)
          .with(
            instance_plan,
            agent_broadcaster,
            vm_deleter,
            ['fake-disk-cid'],
            tags,
            false,
          ).and_return(create_vm_step)
        allow(DeploymentPlan::Steps::UpdateInstanceSettingsStep).to receive(:new)
          .with(instance).and_return(update_settings_step)
        allow(DeploymentPlan::Steps::ElectActiveVmStep).to receive(:new)
          .and_return(elect_active_vm_step)
        allow(elect_active_vm_step).to receive(:perform).with(report) do
          vm_model.active = true
          vm_model.save
        end
        allow(DeploymentPlan::Steps::ApplyVmSpecStep).to receive(:new).and_return(spec_apply_step)
      end

      it 'should create a vm and associate it with an instance' do
        expect(create_vm_step).to receive(:perform).with(report)
        expect(elect_active_vm_step).to receive(:perform).with(report)
        expect(update_settings_step).to receive(:perform).with(report)

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
      end

      it 'should create vm for the instance plans' do
        expect(create_vm_step).to receive(:perform).with(report)

        expect(deployment_plan).to receive(:ip_provider).and_return(ip_provider)

        attach_instance_disks_step = instance_double(DeploymentPlan::Steps::AttachInstanceDisksStep)
        mount_instance_disks_step = instance_double(DeploymentPlan::Steps::MountInstanceDisksStep)
        expect(DeploymentPlan::Steps::AttachInstanceDisksStep).to receive(:new)
          .with(instance_model, tags).and_return(attach_instance_disks_step)
        expect(DeploymentPlan::Steps::MountInstanceDisksStep).to receive(:new)
          .with(instance_model).and_return(mount_instance_disks_step)

        expect(attach_instance_disks_step).to receive(:perform).with(report).once
        expect(mount_instance_disks_step).to receive(:perform).with(report).once
        expect(update_settings_step).to receive(:perform).with(report)

        subject.create_for_instance_plans([instance_plan], deployment_plan.ip_provider, tags)
      end

      describe 'rendering job templates' do
        let(:spec) { instance_double(DeploymentPlan::InstanceSpec, as_template_spec: {}) }
        let(:render_step) { instance_double(DeploymentPlan::Steps::RenderInstanceJobTemplatesStep) }

        before do
          allow(instance_plan).to receive(:spec).and_return(spec)
          allow(DeploymentPlan::Steps::ApplyVmSpecStep).to receive(:new)
            .with(instance_plan).and_return(spec_apply_step)
          allow(DeploymentPlan::Steps::RenderInstanceJobTemplatesStep).to receive(:new)
            .with(instance_plan, template_blob_cache, dns_encoder).and_return(render_step)
        end

        it 're-renders job templates after applying spec' do
          expect(create_vm_step).to receive(:perform).with(report).ordered
          expect(spec_apply_step).to receive(:perform).with(report).ordered
          expect(render_step).to receive(:perform).with(report)

          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        end
      end

      context 'when instance already has associated active_vm' do
        let(:old_vm) { Models::Vm.make(instance: instance_model, cpi: 'cpi1') }

        before { instance_model.active_vm = old_vm }

        it 'should not override the active vm on the instance model' do
          expect(create_vm_step).to receive(:perform).with(report)

          expect(elect_active_vm_step).not_to receive(:perform)
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)

          instance_model.refresh
          old_vm.refresh

          expect(instance_model.active_vm).to eq(old_vm)
        end
      end

      context 'when the instance plan does not need a persistent disk' do
        before do
          allow(instance_plan).to receive(:needs_disk?).and_return(false)
        end

        it 'does not try to attach the disk' do
          expect(create_vm_step).to receive(:perform).with(report)
          expect(DeploymentPlan::Steps::AttachInstanceDisksStep).not_to receive(:new)
          expect(DeploymentPlan::Steps::MountInstanceDisksStep).not_to receive(:new)

          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        end
      end
    end
  end
end
