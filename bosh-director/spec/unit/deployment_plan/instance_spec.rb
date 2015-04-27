require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do
    subject(:instance) { Instance.new(job, index, logger) }
    let(:index) { 0 }

    before { allow(Bosh::Director::Config).to receive(:dns_domain_name).and_return(domain_name) }
    let(:domain_name) { 'test_domain' }

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
        name: 'fake-deployment',
        canonical_name: 'mycloud',
        model: deployment,
        network: net,
      })
    end
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::Job',
        resource_pool: resource_pool,
        deployment: plan,
        name: 'fake-job',
        persistent_disk_pool: disk_pool,
      )
    end
    let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', network: net, name: 'fake-resource-pool') }
    let(:disk_pool) { nil }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:vm) { Vm.new(resource_pool) }
    before do
      allow(resource_pool).to receive(:allocate_vm).and_return(vm)
      allow(resource_pool).to receive(:add_allocated_vm).and_return(vm)
      allow(job).to receive(:instance_state).with(0).and_return('started')
    end

    let(:instance_model) { Bosh::Director::Models::Instance.make }
    let(:vm_model) { Bosh::Director::Models::Vm.make }

    describe '#network_settings' do
      let(:job) do
        instance_double('Bosh::Director::DeploymentPlan::Job', {
          deployment: plan,
          name: 'fake-job',
          canonical_name: 'job',
          starts_on_deploy?: true,
          resource_pool: resource_pool,
        })
      end
      let(:instance_model) { Bosh::Director::Models::Instance.make }

      let(:network_name) { 'net_a' }
      let(:cloud_properties) { {'foo' => 'bar'} }
      let(:dns) { ['1.2.3.4'] }
      let(:dns_record_name) { "0.job.net-a.mycloud.#{domain_name}" }
      let(:ipaddress) { '10.0.0.6' }
      let(:subnet_range) { '10.0.0.1/24' }
      let(:netmask) { '255.255.255.0' }
      let(:gateway) { '10.0.0.1' }

      let(:network_settings) do
        {
          'cloud_properties' => cloud_properties,
          'dns_record_name' => dns_record_name,
          'dns' => dns,
        }
      end

      let(:network_info) do
        {
          'ip' => ipaddress,
          'netmask' => netmask,
          'gateway' => gateway,
        }
      end

      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
          name: 'fake-resource-pool',
          network: network,
        })
      end

      let(:vm) do
        instance_double('Bosh::Director::DeploymentPlan::Vm', {
          :model= => nil,
          :bound_instance= => nil,
          :current_state= => nil,
          :resource_pool => resource_pool,
        })
      end
      before { allow(vm).to receive(:use_reservation).with(reservation).and_return(vm) }
      let(:reservation) { Bosh::Director::NetworkReservation.new_static(ipaddress) }

      let(:current_state) { {'networks' => {network_name => network_info}} }

      before do
        allow(job).to receive(:instance_state).with(0).and_return('started')
        allow(job).to receive(:default_network).and_return({})
      end

      before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

      context 'dynamic network' do
        before { allow(plan).to receive(:network).with(network_name).and_return(network) }
        let(:network) do
          DynamicNetwork.new(plan, {
            'name' => network_name,
            'cloud_properties' => cloud_properties,
            'dns' => dns
          })
        end

        let(:reservation) { Bosh::Director::NetworkReservation.new_dynamic }
        before do
          network.reserve(reservation)
          instance.add_network_reservation(network_name, reservation)
        end

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          net_settings_with_type = network_settings.merge('type' => 'dynamic')
          expect(instance.network_settings).to eql(network_name => net_settings_with_type)

          instance.bind_existing_instance(instance_model, current_state, {})
          expect(instance.network_settings).to eql({network_name => net_settings_with_type.merge(network_info)})
        end
      end

      context 'manual network' do
        before { allow(plan).to receive(:network).with(network_name).and_return(network) }
        let(:network) do
          ManualNetwork.new(plan, {
            'name' => network_name,
            'dns' => dns,
            'subnets' => [{
              'range' => subnet_range,
              'gateway' => gateway,
              'dns' => dns,
              'cloud_properties' => cloud_properties
            }]
          })
        end

        before do
          network.reserve(reservation)
          instance.add_network_reservation(network_name, reservation)
        end

        it 'returns the network settings as set at the network spec' do
          net_settings = {network_name => network_settings.merge(network_info)}
          expect(instance.network_settings).to eql(net_settings)

          instance.bind_existing_instance(instance_model, current_state, {})
          expect(instance.network_settings).to eql(net_settings)
        end
      end

      describe 'temporary errand hack' do
        let(:network) do
          ManualNetwork.new(plan, {
            'name' => network_name,
            'dns' => dns,
            'subnets' => [{
              'range' => subnet_range,
              'gateway' => gateway,
              'dns' => dns,
              'cloud_properties' => cloud_properties
            }]
          })
        end

        before do
          allow(plan).to receive(:network).with(network_name).and_return(network)
          network.reserve(reservation)
        end

        context 'when job is started on deploy' do
          before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

          it 'includes dns_record_name' do
            instance.add_network_reservation(network_name, reservation)
            expect(instance.network_settings['net_a']).to have_key('dns_record_name')
          end
        end

        context 'when job is not started on deploy' do
          before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(false) }

          it 'does not include dns_record_name' do
            instance.add_network_reservation(network_name, reservation)
            expect(instance.network_settings['net_a']).to_not have_key('dns_record_name')
          end
        end
      end
    end

    describe '#disk_size' do
      context 'when instance does not have bound model' do
        it 'raises an error' do
          expect {
            instance.disk_size
          }.to raise_error Bosh::Director::DirectorError
        end
      end

      context 'when instance has bound model' do
        before { instance.bind_unallocated_vm }

        context 'when model has persistent disk' do
          before do
            persistent_disk = Bosh::Director::Models::PersistentDisk.make(size: 1024)
            instance.model.persistent_disks << persistent_disk
          end

          it 'returns its size' do
            expect(instance.disk_size).to eq(1024)
          end
        end

        context 'when model has no persistent disk' do
          it 'returns 0' do
            expect(instance.disk_size).to eq(0)
          end
        end
      end
    end

    describe '#disk_cloud_properties' do
      context 'when instance does not have bound model' do
        it 'raises an error' do
          expect {
            instance.disk_cloud_properties
          }.to raise_error Bosh::Director::DirectorError
        end
      end

      context 'when instance has bound model' do
        before { instance.bind_unallocated_vm }

        context 'when model has persistent disk' do
          let(:disk_cloud_properties) { { 'fake-disk-key' => 'fake-disk-value' } }

          before do
            persistent_disk = Bosh::Director::Models::PersistentDisk.make(size: 1024, cloud_properties: disk_cloud_properties)
            instance.model.persistent_disks << persistent_disk
          end

          it 'returns its cloud properties' do
            expect(instance.disk_cloud_properties).to eq(disk_cloud_properties)
          end
        end

        context 'when model has no persistent disk' do
          it 'returns empty hash' do
            expect(instance.disk_cloud_properties).to eq({})
          end
        end
      end
    end

    describe '#bind_unallocated_vm' do
      let(:index) { 2 }
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, name: 'dea') }
      let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', network: net) }
      let(:old_ip) { NetAddr::CIDR.create('10.0.0.5').to_i }
      let(:vm_ip) { NetAddr::CIDR.create('10.0.0.3').to_i }
      let(:old_reservation) { Bosh::Director::NetworkReservation.new_dynamic(old_ip) }
      let(:vm_reservation) { Bosh::Director::NetworkReservation.new_dynamic(vm_ip) }
      let(:vm) { Vm.new(resource_pool) }

      before do
        allow(job).to receive(:instance_state).with(2).and_return('started')
        allow(job).to receive(:resource_pool).and_return(resource_pool)
        vm.use_reservation(vm_reservation)
      end

      it 'binds a VM from job resource pool (real VM exists)' do
        vm.model = Bosh::Director::Models::Vm.make

        expect(resource_pool).to receive(:allocate_vm).and_return(vm)

        instance.add_network_reservation('net_a', old_reservation)
        instance.bind_unallocated_vm

        expect(instance.model).not_to be_nil
        expect(instance.vm).to eq(vm)
        expect(vm.bound_instance).to be_nil
        expect(vm.network_reservation.ip).to eq(vm_ip)
      end

      it "binds a VM from job resource pool (real VM doesn't exist)" do
        expect(vm.model).to be_nil

        expect(resource_pool).to receive(:allocate_vm).and_return(vm)
        expect(net).to receive(:release).with(vm_reservation)

        instance.add_network_reservation('net_a', old_reservation)
        instance.bind_unallocated_vm

        expect(instance.model).not_to be_nil
        expect(instance.vm).to eq(vm)
        expect(vm.bound_instance).to eq(instance)
        expect(vm.network_reservation).to be_nil
      end
    end

    describe '#bind_existing_instance' do
      let(:job) { Job.new(plan) }

      before { job.resource_pool = resource_pool }
      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
          name: 'fake-resource-pool',
          # spec: 'fake-resource-pool-spec',
          network: network,
        })
      end
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

      before { allow(resource_pool).to receive(:add_allocated_vm).and_return(vm) }
      let(:vm) { Vm.new(resource_pool) }

      let(:instance_model) { Bosh::Director::Models::Instance.make }

      it 'raises an error if instance already has a model' do
        state = {}
        reservations = {}

        instance.bind_existing_instance(instance_model, state, reservations)

        expect {
          instance.bind_existing_instance(instance_model, state, reservations)
        }.to raise_error(Bosh::Director::DirectorError, /model is already bound/)
      end

      it 'sets the instance model and state' do
        state = {}
        reservations = {}

        instance.bind_existing_instance(instance_model, state, reservations)

        expect(instance.model).to eq(instance_model)
        expect(instance.current_state).to eq(state)
      end

      it 'takes the new reservation for each existing reservation with the same network name' do
        existing_reservations = {
          'fake-network1' => Bosh::Director::NetworkReservation.new_dynamic,
          'fake-network2' => Bosh::Director::NetworkReservation.new_dynamic,
        }
        existing_reservations.each { |name, reservation| instance.add_network_reservation(name, reservation) }

        state = {}
        new_reservations = {
          'fake-network1' => Bosh::Director::NetworkReservation.new_static,
        }

        expect(existing_reservations['fake-network1']).to receive(:take).with(new_reservations['fake-network1'])
        expect(existing_reservations['fake-network2']).to_not receive(:take)

        instance.bind_existing_instance(instance_model, state, new_reservations)
      end

      it "adds the existing VM as allocated on the job's resource pool" do
        instance_model.vm = vm_model

        state = {}
        reservations = {}

        expect(resource_pool).to receive(:add_allocated_vm).with(no_args).and_return(vm)

        instance.bind_existing_instance(instance_model, state, reservations)

        expect(vm.model).to be(vm_model)
        expect(vm.bound_instance).to be(instance)
        expect(vm.current_state).to be(state)

        expect(instance.vm).to be(vm)
      end
    end

    describe '#apply_partial_vm_state' do
      let(:job) { Job.new(plan) }

      before do
        job.templates = [template]
        job.name = 'fake-job'
      end

      let(:template) do
        instance_double('Bosh::Director::DeploymentPlan::Template', {
          name: 'fake-template',
          version: 'fake-template-version',
          sha1: 'fake-template-sha1',
          blobstore_id: 'fake-template-blobstore-id',
          logs: nil,
        })
      end

      before { job.resource_pool = resource_pool }
      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
          name: 'fake-resource-pool',
          network: network,
        })
      end
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }
      let(:vm) { Vm.new(resource_pool) }

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
      before { allow(agent_client).to receive(:apply) }

      before { allow(Bosh::Director::AgentClient).to receive(:with_defaults).with(vm_model.agent_id).and_return(agent_client) }

      before do
        # Create a new VM
        vm.model = vm_model
        vm.current_state = { 'fake-vm-existing-state' => true }

        # Allocate the new vm to the resource pool specified by the job spec
        allow(resource_pool).to receive(:allocate_vm).and_return(vm)
        instance.bind_unallocated_vm
      end

      it 'sends apply message to an agent that includes existing vm state, new job spec, instance index' do
        expect(agent_client).to receive(:apply).with(
          'fake-vm-existing-state' => true,
          'job' => {
            'name' => 'fake-job',
            'templates' => [{
              'name' => 'fake-template',
              'version' => 'fake-template-version',
              'sha1' => 'fake-template-sha1',
              'blobstore_id' => 'fake-template-blobstore-id',
            }],
            'template' => 'fake-template',
            'version' => 'fake-template-version',
            'sha1' => 'fake-template-sha1',
            'blobstore_id' => 'fake-template-blobstore-id',
          },
          'index' => 0,
        )
        instance.apply_partial_vm_state
      end

      def self.it_rolls_back_instance_and_vm_state(error)
        it 'does not point instance to the vm so that during the next deploy instance can be re-associated with new vm' do
          expect {
            expect { instance.apply_partial_vm_state }.to raise_error(error)
          }.to_not change { instance.model.refresh.vm }.from(nil)
        end

        it 'does not change apply spec on vm model' do
          expect {
            expect { instance.apply_partial_vm_state }.to raise_error(error)
          }.to_not change { vm_model.refresh.apply_spec }.from(nil)
        end
      end

      context 'when agent apply succeeds' do
        context 'when saving state changes to the database succeeds' do
          it 'the instance points to the vm' do
            expect {
              instance.apply_partial_vm_state
            }.to change { instance.model.refresh.vm }.from(nil).to(vm_model)
          end

          it 'the vm apply spec is set to new state' do
            expect {
              instance.apply_partial_vm_state
            }.to change { vm_model.refresh.apply_spec }.from(nil).to(
              hash_including(
                'fake-vm-existing-state' => true,
                'job' => hash_including('name' => 'fake-job'),
              ),
            )
          end

          it 'the instance current state is set to new state' do
            expect {
              instance.apply_partial_vm_state
            }.to change { instance.job_changed? }.from(true).to(false)
          end
        end

        context 'when update vm instance in the database fails' do
          error = Exception.new('error')
          before { allow(instance.model).to receive(:_update_without_checking).and_raise(error) }
          it_rolls_back_instance_and_vm_state(error)
        end

        context 'when update vm apply spec in the database fails' do
          error = Exception.new('error')
          before { allow(vm_model).to receive(:_update_without_checking).and_raise(error) }
          it_rolls_back_instance_and_vm_state(error)
        end
      end

      context 'when agent apply fails' do
        error = Bosh::Director::RpcTimeout.new('error')
        before { allow(agent_client).to receive(:apply).and_raise(error) }
        it_rolls_back_instance_and_vm_state(error)
      end
    end

    describe '#apply_vm_state' do
      let(:job) { Job.new(plan) }

      before do
        job.templates = [template]
        job.name = 'fake-job'
        job.default_network = {}
      end

      let(:template) do
        instance_double('Bosh::Director::DeploymentPlan::Template', {
          name: 'fake-template',
          version: 'fake-template-version',
          sha1: 'fake-template-sha1',
          blobstore_id: 'fake-template-blobstore-id',
          logs: nil,
        })
      end

      before { job.resource_pool = resource_pool }
      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
          name: 'fake-resource-pool',
          spec: 'fake-resource-pool-spec',
        })
      end

      before { allow(job).to receive(:spec).with(no_args).and_return('fake-job-spec') }

      let(:vm) { Vm.new(resource_pool) }

      let(:network) do
        instance_double('Bosh::Director::DeploymentPlan::Network', {
          name: 'fake-network',
          network_settings: 'fake-network-settings',
        })
      end

      before { allow(resource_pool).to receive(:network).and_return(network) }

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
      before { allow(agent_client).to receive(:apply) }

      before { allow(Bosh::Director::AgentClient).to receive(:with_defaults).with(vm_model.agent_id).and_return(agent_client) }

      before { allow(plan).to receive(:network).with('fake-network').and_return(network) }

      before do
        instance.configuration_hash = 'fake-desired-configuration-hash'

        # Create a new VM
        vm.model = vm_model
        vm.current_state = {
          'fake-vm-existing-state' => true,
        }

        reservation = Bosh::Director::NetworkReservation.new_dynamic
        vm.network_reservation = reservation
        instance.add_network_reservation('fake-network', reservation)

        # Allocate the new vm to the resource pool specified by the job spec
        allow(resource_pool).to receive(:allocate_vm).and_return(vm)
        instance.bind_unallocated_vm
        instance.apply_partial_vm_state
      end

      context 'when persistent disk size is 0' do
        before { allow(instance).to receive(:disk_size).with(no_args).and_return(0) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          state = {
            'deployment' => 'fake-deployment',
            'networks' => {'fake-network' => 'fake-network-settings'},
            'resource_pool' => 'fake-resource-pool-spec',
            'job' => 'fake-job-spec',
            'index' => 0,
          }

          expect(vm_model).to receive(:update).with(apply_spec: state).ordered
          expect(agent_client).to receive(:apply).with(state).ordered

          returned_state = state.merge('configuration_hash' => 'fake-desired-configuration-hash')
          expect(agent_client).to receive(:get_state).and_return(returned_state).ordered

          expect {
            instance.apply_vm_state
          }.to change { instance.configuration_changed? }.from(true).to(false)
        end
      end

      context 'when persistent disk size is greater than 0' do
        before { allow(instance).to receive(:disk_size).with(no_args).and_return(100) }

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          state = {
            'deployment' => 'fake-deployment',
            'networks' => {'fake-network' => 'fake-network-settings'},
            'resource_pool' => 'fake-resource-pool-spec',
            'job' => 'fake-job-spec',
            'index' => 0,
            'persistent_disk' => 100,
          }

          expect(vm_model).to receive(:update).with(apply_spec: state).ordered
          expect(agent_client).to receive(:apply).with(state).ordered

          returned_state = state.merge('configuration_hash' => 'fake-desired-configuration-hash')
          expect(agent_client).to receive(:get_state).and_return(returned_state).ordered

          expect {
            instance.apply_vm_state
          }.to change { instance.configuration_changed? }.from(true).to(false)
        end
      end
    end

    describe '#sync_state_with_db' do
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, name: 'dea', resource_pool: resource_pool) }
      let(:index) { 3 }

      it 'deployment plan -> DB' do
        allow(job).to receive(:instance_state).with(3).and_return('stopped')

        expect {
          instance.sync_state_with_db
        }.to raise_error(Bosh::Director::DirectorError, /model is not bound/)

        instance.bind_unallocated_vm
        expect(instance.model.state).to eq('started')
        instance.sync_state_with_db
        expect(instance.state).to eq('stopped')
        expect(instance.model.state).to eq('stopped')
      end

      it 'DB -> deployment plan' do
        allow(job).to receive(:instance_state).with(3).and_return(nil)

        instance.bind_unallocated_vm
        instance.model.update(:state => 'stopped')

        instance.sync_state_with_db
        expect(instance.model.state).to eq('stopped')
        expect(instance.state).to eq('stopped')
      end

      it 'needs to find state in order to sync it' do
        allow(job).to receive(:instance_state).with(3).and_return(nil)

        instance.bind_unallocated_vm
        expect(instance.model).to receive(:state).and_return(nil)

        expect {
          instance.sync_state_with_db
        }.to raise_error(Bosh::Director::InstanceTargetStateUndefined)
      end
    end

    describe '#job_changed?' do
      let(:job) { Job.new(plan) }
      before do
        job.templates = [template]
        job.name = state['job']['name']
      end
      let(:template) do
        instance_double('Bosh::Director::DeploymentPlan::Template', {
          name: state['job']['name'],
          version: state['job']['version'],
          sha1: state['job']['sha1'],
          blobstore_id: state['job']['blobstore_id'],
          logs: nil,
        })
      end
      let(:state) do
        {
          'job' => {
            'name' => 'hbase_slave',
            'template' => 'hbase_slave',
            'version' => '0+dev.9',
            'sha1' => 'a8ab636b7c340f98891178096a44c09487194f03',
            'blobstore_id' => 'e2e4e58e-a40e-43ec-bac5-fc50457d5563'
          }
        }
      end

      before { job.resource_pool = resource_pool }
      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
          name: 'fake-resource-pool',
          network: network,
        })
      end
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }
      let(:vm) { Vm.new(resource_pool) }

      context 'when an instance exists (with the same job name & instance index)' do
        before do
          allow(resource_pool).to receive(:add_allocated_vm).and_return(vm)

          instance_model = Bosh::Director::Models::Instance.make
          instance.bind_existing_instance(instance_model, instance_state, {})
        end

        context 'that fully matches the job spec' do
          let(:instance_state) { {'job' => job.spec} }

          it 'returns false' do
            expect(instance.job_changed?).to eq(false)
          end
        end

        context 'that does not match the job spec' do
          let(:instance_state) { {'job' => job.spec.merge('version' => 'old-version')} }

          it 'returns true' do
            expect(instance.job_changed?).to eq(true)
          end
        end
      end

      context 'when the instance is being created' do
        let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
        before do
          allow(Bosh::Director::AgentClient).to receive(:with_defaults).with(vm_model.agent_id).and_return(agent_client)
          allow(agent_client).to receive(:apply)
        end

        before do
          # Create a new VM
          vm.model = vm_model
          vm.current_state = {} # new VM; actual VM does not have any job associated

          # Allocate the new vm to the resource pool specified by the job spec
          allow(resource_pool).to receive(:allocate_vm).and_return(vm)
          instance.bind_unallocated_vm

          # Set the job spec on the Agent and the DB (instance model & vm model)
          instance.apply_partial_vm_state
        end

        it 'returns false' do
          expect(instance.job_changed?).to eq(false)
        end
      end
    end

    describe '#resource_pool_changed?' do
      let(:resource_pool) { ResourcePool.new(plan, resource_pool_manifest, logger) }

      let(:resource_pool_manifest) do
        {
          'name' => 'fake-resource-pool',
          'env' => {'key' => 'value'},
          'cloud_properties' => {},
          'stemcell' => {
            'name' => 'fake-stemcell',
            'version' => '1.0.0',
          },
          'network' => 'fake-network',
        }
      end

      let(:resource_pool_spec) do
        {
          'name' => 'fake-resource-pool',
          'cloud_properties' => {},
          'stemcell' => {
            'name' => 'fake-stemcell',
            'version' => '1.0.0',
          },
        }
      end

      let(:job) { Job.new(plan) }

      before { allow(plan).to receive(:network).with('fake-network').and_return(network) }
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

      before do
        allow(job).to receive(:instance_state).with(0).and_return('started')
        allow(job).to receive(:resource_pool).and_return(resource_pool)
        allow(plan).to receive(:recreate).and_return(false)
      end

      it 'detects resource pool change when instance VM env changes' do
        instance_model = Bosh::Director::Models::Instance.make

        # set up in-memory domain model state
        instance.bind_existing_instance(instance_model, {'resource_pool' => resource_pool_spec}, {})

        # set DB to match real instance/vm
        instance_model.vm.update(:env => {'key' => 'value'})
        expect(instance.resource_pool_changed?).to be(false)

        # change DB to NOT match real instance/vm
        instance_model.vm.update(env: {'key' => 'value2'})
        expect(instance.resource_pool_changed?).to be(true)
      end
    end

    describe 'persistent_disk_changed?' do
      context 'when disk pool with size 0 is used' do
        let(:disk_pool) do
          Bosh::Director::DeploymentPlan::DiskPool.parse(
            {
              'name' => 'fake-name',
              'disk_size' => 0,
              'cloud_properties' => {'type' => 'fake-type'},
            }
          )
        end

        before { instance.bind_existing_instance(instance_model, {}, {}) }

        context 'when disk_size is still 0' do
          it 'returns false' do
            expect(instance.persistent_disk_changed?).to be(false)
          end
        end
      end
    end

    describe '#spec' do
      let(:job_spec) { {name: 'job', release: 'release', templates: []} }
      let(:release_spec) { {name: 'release', version: '1.1-dev'} }
      let(:resource_pool_spec) { {'name' => 'default', 'stemcell' => {'name' => 'stemcell-name', 'version' => '1.0'}} }
      let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
      let(:properties) { {'key' => 'value'} }
      let(:reservation) { Bosh::Director::NetworkReservation.new_dynamic }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}} }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: resource_pool_spec) }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
      let(:network) {
        network = DynamicNetwork.new(plan, network_spec)
        network.reserve(reservation)
        network
      }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          deployment: plan,
          spec: job_spec,
          canonical_name: 'job',
          instances: ['instance0'],
          release: release,
          default_network: {},
          resource_pool: resource_pool,
          package_spec: packages,
          persistent_disk_pool: disk_pool,
          starts_on_deploy?: true,
          properties: properties)
      }
      let(:disk_pool) { instance_double('Bosh::Director::DeploymentPlan::DiskPool', disk_size: 0, spec: disk_pool_spec) }
      let(:disk_pool_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {} } }

      before do
        allow(plan).to receive(:network).and_return(network)
        allow(job).to receive(:instance_state).with(index).and_return('started')
      end

      it 'returns instance spec' do
        network_name = network_spec['name']
        instance.add_network_reservation(network_name, reservation)

        spec = instance.spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['job']).to eq(job_spec)
        expect(spec['index']).to eq(index)
        expect(spec['networks']).to include(network_name)

        expect_dns_name = "#{index}.#{job.canonical_name}.#{network_name}.#{plan.canonical_name}.#{domain_name}"
        expect(spec['networks'][network_name]).to include(
          'type' => 'dynamic',
          'cloud_properties' => network_spec['cloud_properties'],
          'dns_record_name' => expect_dns_name
        )

        expect(spec['resource_pool']).to eq(resource_pool_spec)
        expect(spec['packages']).to eq(packages)
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(disk_pool_spec)
        expect(spec['configuration_hash']).to be_nil
        expect(spec['properties']).to eq(properties)
        expect(spec['dns_domain_name']).to eq(domain_name)
      end

      it 'includes rendered_templates_archive key after rendered templates were archived' do
        instance.rendered_templates_archive =
          Bosh::Director::Core::Templates::RenderedTemplatesArchive.new('fake-blobstore-id', 'fake-sha1')

        expect(instance.spec['rendered_templates_archive']).to eq(
          'blobstore_id' => 'fake-blobstore-id',
          'sha1' => 'fake-sha1',
        )
      end

      it 'does not include rendered_templates_archive key before rendered templates were archived' do
        expect(instance.spec).to_not have_key('rendered_templates_archive')
      end

      it 'does not require persistent_disk_pool' do
        allow(job).to receive(:persistent_disk_pool).and_return(nil)

        spec = instance.spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end
    end

    describe '#bind_to_vm_model' do
      before do
        instance.bind_unallocated_vm
        instance.bind_to_vm_model(vm_model)
      end

      it 'updates instance model with new vm model' do
        expect(instance.model.refresh.vm).to eq(vm_model)
        expect(instance.vm.model).to eq(vm_model)
        expect(instance.vm.bound_instance).to eq(instance)
      end
    end
  end
end
