require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do
    subject(:instance) { Instance.new(job, index, state, plan, current_state, availability_zone, logger) }
    let(:index) { 0 }
    let(:state) { 'started' }
    let(:in_memory_ip_repo) { InMemoryIpRepo.new(logger) }
    let(:vip_repo) { VipRepo.new(logger) }
    let(:ip_provider) { IpProviderV2.new(in_memory_ip_repo, vip_repo, false, logger) }

    before { allow(Bosh::Director::Config).to receive(:dns_domain_name).and_return(domain_name) }
    let(:domain_name) { 'test_domain' }
    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
    end

    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:plan_recreate) { false }
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
          name: 'fake-deployment',
          canonical_name: 'mycloud',
          model: deployment,
          network: net,
          using_global_networking?: true,
          recreate: plan_recreate
        })
    end
    let(:network_resolver) { GlobalNetworkResolver.new(plan) }
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::Job',
        resource_pool: resource_pool,
        deployment: plan,
        name: 'fake-job',
        persistent_disk_pool: disk_pool,
        compilation?: false
      )
    end
    let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'fake-resource-pool') }
    let(:disk_pool) { nil }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:availability_zone) { instance_double('Bosh::Director::DeploymentPlan::AvailabilityZone', name: 'foo-az') }
    let(:vm) { Vm.new }
    before do
      allow(job).to receive(:instance_state).with(0).and_return('started')
    end

    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment) }
    let(:vm_model) { Bosh::Director::Models::Vm.make }

    let(:current_state) { {'current' => 'state'} }

    describe '#network_settings' do
      let(:job) do
        instance_double('Bosh::Director::DeploymentPlan::Job', {
            deployment: plan,
            name: 'fake-job',
            canonical_name: 'job',
            starts_on_deploy?: true,
            resource_pool: resource_pool,
            compilation?: false
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
          })
      end

      let(:vm) do
        instance_double('Bosh::Director::DeploymentPlan::Vm', {
            :model= => nil,
            :bound_instance= => nil,
          })
      end

      let(:reservation) { Bosh::Director::StaticNetworkReservation.new(instance, network, ipaddress) }

      let(:current_state) { {'networks' => {network_name => network_info}} }

      before do
        allow(job).to receive(:instance_state).with(0).and_return('started')
        allow(job).to receive(:default_network).and_return({})
      end

      before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

      context 'dynamic network' do
        before { allow(plan).to receive(:network).with(network_name).and_return(network) }
        let(:network) do
          subnets = [DynamicNetworkSubnet.new(dns, cloud_properties, 'az-name')]
          DynamicNetwork.new(network_name, network_name, subnets, logger)
        end

        let(:reservation) { Bosh::Director::DynamicNetworkReservation.new(instance, network) }
        before do
          ip_provider.reserve(reservation)
          instance.add_network_reservation(reservation)
        end

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          expect(instance.network_settings).to eql({
                'net_a' => {
                  'type' => 'dynamic',
                  'cloud_properties' => {
                    'foo' => 'bar'
                  },
                  'dns' => ['1.2.3.4'],
                  'dns_record_name' => '0.job.net-a.mycloud.test_domain',
                  'ip' => '10.0.0.6',
                  'netmask' => '255.255.255.0',
                  'gateway' => '10.0.0.1'}
              })
        end

        it '#network_changed? should return true' do
          expect(instance.networks_changed?).to be(true)
        end

        it '#network_changed? should log the network changes' do
          expect(logger).to receive(:debug).with('networks_changed? changed FROM: ' +
                '{"net_a"=>{"ip"=>"10.0.0.6", "netmask"=>"255.255.255.0", "gateway"=>"10.0.0.1"}}' +
                ' TO: {"net_a"=>{"type"=>"dynamic", "cloud_properties"=>{"foo"=>"bar"}, "dns"=>["1.2.3.4"], ' +
                '"dns_record_name"=>"0.job.net-a.mycloud.test_domain", "ip"=>"10.0.0.6", "netmask"=>"255.255.255.0", "gateway"=>"10.0.0.1"}}')
          instance.networks_changed?
        end

        describe '#dns_changed?' do
          describe 'when the dns record for the instance is not found' do
            it '#dns_changed? should return true' do
              expect(instance.dns_changed?).to be(true)
            end
            it 'should log the dns changes' do
              expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name '0.job.net-a.mycloud.test_domain' and ip '10.0.0.6' was not found in the db.")
              instance.dns_changed?
            end
          end

          describe 'when the dns record for the instance is found' do
            before do
              ::Bosh::Director::Models::Dns::Record.create(:name => '0.job.net-a.mycloud.test_domain', :type => 'A', :content => '10.0.0.6')
            end

            it '#dns_changed? should return false' do
              expect(instance.dns_changed?).to be(false)
            end
          end
        end
      end

      context 'manual network' do
        before { allow(plan).to receive(:network).with(network_name).and_return(network) }
        let(:network) do
          ManualNetwork.new({
              'name' => network_name,
              'dns' => dns,
              'subnets' => [{
                  'range' => subnet_range,
                  'gateway' => gateway,
                  'dns' => dns,
                  'cloud_properties' => cloud_properties
                }]
            },
            [],
            network_resolver,
            Bosh::Director::DeploymentPlan::IpProviderFactory.new(logger, {}),
            logger
          )
        end

        before do
          instance.add_network_reservation(reservation)
        end

        it 'returns the network settings as set at the network spec' do
          net_settings = {network_name => network_settings.merge(network_info)}
          expect(instance.network_settings).to eql(net_settings)

          instance.bind_existing_instance_model(instance_model)
          expect(instance.network_settings).to eql(net_settings)
        end
      end

      describe 'temporary errand hack' do

        let(:network) do
          ManualNetwork.new({
              'name' => network_name,
              'dns' => dns,
              'subnets' => [{
                  'range' => subnet_range,
                  'gateway' => gateway,
                  'dns' => dns,
                  'cloud_properties' => cloud_properties,
                  'availability_zone' => instance.availability_zone.name,
                }]
            },
            [instance.availability_zone],
            network_resolver,
            Bosh::Director::DeploymentPlan::IpProviderFactory.new(logger, {}),
            logger
          )

        end
        let(:reservation) { Bosh::Director::DynamicNetworkReservation.new(instance, network) }

        before do
          allow(plan).to receive(:network).with(network_name).and_return(network)
          ip_provider.reserve(reservation)
        end

        context 'when job is started on deploy' do
          before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

          it 'includes dns_record_name' do
            instance.add_network_reservation(reservation)
            expect(instance.network_settings['net_a']).to have_key('dns_record_name')
          end
        end

        context 'when job is not started on deploy' do
          before { allow(job).to receive(:starts_on_deploy?).with(no_args).and_return(false) }

          it 'does not include dns_record_name' do
            instance.add_network_reservation(reservation)
            expect(instance.network_settings['net_a']).to_not have_key('dns_record_name')
          end
        end
      end
    end

    describe '#packages_changed?' do
      let(:job) { Job.new(plan, logger) }

      describe 'when packages have changed' do
        let(:current_state) { {'packages' => {'changed' => 'value'}} }

        it 'should return true' do
          expect(instance.packages_changed?).to eq(true)
        end

        it 'should log changes' do
          expect(logger).to receive(:debug).with('packages_changed? changed FROM: {"changed"=>"value"} TO: {}')
          instance.packages_changed?
        end
      end

      describe 'when packages have not changed' do
        let(:current_state) { {'packages' => {}} }

        it 'should return false' do
          expect(instance.packages_changed?).to eq(false)
        end
      end
    end

    describe '#configuration_changed?' do
      let(:job) { Job.new(plan, logger) }

      describe 'when the configuration has changed' do
        let(:current_state) { {'configuration_hash' => {'changed' => 'value'}} }

        it 'should return true' do
          expect(instance.configuration_changed?).to eq(true)
        end

        it 'should log the configuration changed reason' do
          expect(logger).to receive(:debug).with('configuration_changed? changed FROM: {"changed"=>"value"} TO: ')
          instance.configuration_changed?
        end
      end

      describe 'when the configuration has not changed' do
        it 'should return false' do
          expect(instance.configuration_changed?).to eq(false)
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
          let(:disk_cloud_properties) { {'fake-disk-key' => 'fake-disk-value'} }

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
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, name: 'dea', compilation?: false) }
      let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }
      let(:old_ip) { NetAddr::CIDR.create('10.0.0.5').to_i }
      let(:vm_ip) { NetAddr::CIDR.create('10.0.0.3').to_i }
      let(:vm) { Vm.new }

      before do
        allow(job).to receive(:instance_state).with(2).and_return('started')
        allow(job).to receive(:resource_pool).and_return(resource_pool)
      end

      it 'creates a new VM and binds it the instance' do
        instance.bind_unallocated_vm

        expect(instance.model).not_to be_nil
        expect(instance.vm).not_to be_nil
        expect(instance.vm.bound_instance).to eq(instance)
      end

      it 'creates a new uuid for each instance' do
        allow(SecureRandom).to receive(:uuid).and_return('uuid-1', 'uuid-2')
        first_instance = Instance.new(job, index, state, plan, current_state, availability_zone, logger)
        first_instance.bind_unallocated_vm
        first_uuid = first_instance.uuid
        index = 1
        second_instance = Instance.new(job, index, state, plan, current_state, availability_zone, logger)
        second_instance.bind_unallocated_vm
        second_uuid = second_instance.uuid
        expect(first_uuid).to_not be_nil
        expect(second_uuid).to_not be_nil
        expect(first_uuid).to_not eq(second_uuid)
      end
    end

    describe '#bind_existing_instance' do
      let(:job) { Job.new(plan, logger) }

      before { job.resource_pool = resource_pool }
      let(:resource_pool) do
        instance_double('Bosh::Director::DeploymentPlan::ResourcePool', {
            name: 'fake-resource-pool',
          })
      end
      let(:network) do
        instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network', reserve: nil)
      end

      let(:instance_model) { Bosh::Director::Models::Instance.make }

      it 'raises an error if instance already has a model' do
        instance.bind_existing_instance_model(instance_model)

        expect {
          instance.bind_existing_instance_model(instance_model)
        }.to raise_error(Bosh::Director::DirectorError, /model is already bound/)
      end

      it 'sets the instance model' do
        instance.bind_existing_instance_model(instance_model)
        expect(instance.model).to eq(instance_model)
        expect(instance.vm).to_not be_nil
        expect(instance.vm.model).to be(instance_model.vm)
        expect(instance.vm.bound_instance).to be(instance)
      end
    end

    describe '#apply_vm_state' do
      let(:job) { Job.new(plan, logger) }

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

      let(:network) do
        instance_double('Bosh::Director::DeploymentPlan::Network', {
            name: 'fake-network',
            network_settings: 'fake-network-settings',
          })
      end

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
      before { allow(agent_client).to receive(:apply) }

      before { allow(Bosh::Director::AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client) }

      before { allow(plan).to receive(:network).with('fake-network').and_return(network) }

      before do
        instance.configuration_hash = 'fake-desired-configuration-hash'

        reservation = Bosh::Director::DynamicNetworkReservation.new(instance, network)
        instance.add_network_reservation(reservation)

        instance.bind_unallocated_vm
        instance.bind_to_vm_model(vm_model)
      end

      context 'when persistent disk size is 0' do
        before do
          state = {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'id' => 'uuid-1',
            'networks' => {'fake-network' => 'fake-network-settings'},
            'resource_pool' => 'fake-resource-pool-spec',
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test_domain',
            'persistent_disk' => 0
          }

          expect(vm_model).to receive(:update).with(apply_spec: state).ordered
          expect(agent_client).to receive(:apply).with(state).ordered

          returned_state = state.merge({'networks' => {'fake-network' => 'fake-new-network-settings'}})
          expect(agent_client).to receive(:get_state).and_return(returned_state).ordered
        end

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          instance.apply_vm_state
          expect(instance.networks_changed?).to be_truthy
        end
      end

      context 'when persistent disk size is greater than 0' do
        before do
          job.persistent_disk = 100
        end

        it 'updates the model with the spec, applies the state to the agent, and sets the current state of the instance' do
          state = {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'id' => 'uuid-1',
            'networks' => {'fake-network' => 'fake-network-settings'},
            'resource_pool' => 'fake-resource-pool-spec',
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test_domain',
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
      let(:job) do
        instance_double(
          'Bosh::Director::DeploymentPlan::Job',
          deployment: plan,
          name: 'dea',
          resource_pool: resource_pool,
          compilation?: false
        )
      end
      let(:index) { 3 }

      context 'when desired state is stopped' do
        let(:state) { 'stopped' }

        it 'deployment plan -> DB' do
          expect {
            instance.sync_state_with_db
          }.to raise_error(Bosh::Director::DirectorError, /model is not bound/)

          instance.bind_unallocated_vm
          expect(instance.model.state).to eq('started')
          instance.sync_state_with_db
          expect(instance.state).to eq('stopped')
          expect(instance.model.state).to eq('stopped')
        end
      end

      context 'when desired state is not set' do
        let(:state) { nil }

        it 'DB -> deployment plan' do
          instance.bind_unallocated_vm
          instance.model.update(:state => 'stopped')

          instance.sync_state_with_db
          expect(instance.model.state).to eq('stopped')
          expect(instance.state).to eq('stopped')
        end

        it 'needs to find state in order to sync it' do
          instance.bind_unallocated_vm
          expect(instance.model).to receive(:state).and_return(nil)

          expect {
            instance.sync_state_with_db
          }.to raise_error(Bosh::Director::InstanceTargetStateUndefined)
        end
      end
    end

    describe '#job_changed?' do
      let(:job) { Job.new(plan, logger) }
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
          })
      end
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }
      let(:vm) { Vm.new }

      context 'when an instance exists (with the same job name & instance index)' do
        before do
          instance_model = Bosh::Director::Models::Instance.make
          instance.bind_existing_instance_model(instance_model)
        end

        context 'that fully matches the job spec' do
          let(:current_state) { {'job' => job.spec} }

          it 'returns false' do
            expect(instance.job_changed?).to eq(false)
          end
        end

        context 'that does not match the job spec' do
          let(:current_state) { {'job' => job.spec.merge('version' => 'old-version')} }

          it 'returns true' do
            expect(instance.job_changed?).to eq(true)
          end

          it 'logs the change' do
            expect(logger).to receive(:debug).with(/job_changed\? changed FROM: .* TO: .*/)
            instance.job_changed?
          end
        end
      end
    end

    describe '#resource_pool_changed?' do
      let(:resource_pool) { ResourcePool.new(resource_pool_manifest, logger) }

      let(:resource_pool_manifest) do
        {
          'name' => 'fake-resource-pool',
          'env' => {'key' => 'value'},
          'cloud_properties' => {},
          'stemcell' => {
            'name' => 'fake-stemcell',
            'version' => '1.0.0',
          },
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

      let(:job) { Job.new(plan, logger) }

      before { allow(plan).to receive(:network).with('fake-network').and_return(network) }
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

      before do
        allow(job).to receive(:instance_state).with(0).and_return('started')
        job.resource_pool = resource_pool
      end

      let(:current_state) { {'resource_pool' => resource_pool_spec} }

      describe 'when nothing changes' do
        it 'should return false' do
          expect(instance.resource_pool_changed?).to_not be(true)
        end
      end

      describe 'when the resource pool spec does not match the existing state' do
        before do
          resource_pool_spec['cloud_properties'] = {'bar' => 'baz'}
        end

        it 'should return changed' do
          expect(instance.resource_pool_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('resource_pool_changed? changed FROM: ' +
                '{"name"=>"fake-resource-pool", "cloud_properties"=>{"bar"=>"baz"}, "stemcell"=>{"name"=>"fake-stemcell", "version"=>"1.0.0"}} ' +
                'TO: ' +
                '{"name"=>"fake-resource-pool", "cloud_properties"=>{}, "stemcell"=>{"name"=>"fake-stemcell", "version"=>"1.0.0"}}')
          instance.resource_pool_changed?
        end
      end

      describe 'when the instance is initialized with "recreate" state' do
        let(:state) { 'recreate' }

        it 'should return changed' do
          expect(instance.resource_pool_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('resource_pool_changed? instance was initialized with "recreate" state')
          instance.resource_pool_changed?
        end
      end

      describe "when the job's deployment is configured for recreate" do
        let(:plan_recreate) { true }

        it 'should return changed' do
          expect(plan.recreate).to be(true)
          expect(instance.resource_pool_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('resource_pool_changed? job deployment is configured with "recreate" state')
          instance.resource_pool_changed?
        end
      end

      describe 'when the resource pool env changes' do
        it 'detects resource pool change when instance VM env changes' do
          instance_model = Bosh::Director::Models::Instance.make
          instance.bind_existing_instance_model(instance_model)

          instance_model.vm.update(env: {'key' => 'value2'})
          expect(instance.resource_pool_changed?).to be(true)
        end

        it 'should log the diff when the resource pool env changes' do
          instance_model = Bosh::Director::Models::Instance.make

          # set up in-memory domain model state
          instance.bind_existing_instance_model(instance_model)

          instance_model.vm.update(env: {'key' => 'previous_value'})
          expect(logger).to receive(:debug).with('resource_pool_changed? changed FROM: {"key"=>"previous_value"} TO: {"key"=>"value"}')
          instance.resource_pool_changed?
        end
      end
    end

    describe '#state_changed?' do
      describe 'when there is no state changed' do
        before do
          current_state['job_state'] = 'running'
        end

        it 'should return false' do
          expect(instance.state_changed?).to eq(false)
        end
      end

      describe 'when the state is detached' do
        let(:state) { 'detached' }

        it 'should return true' do
          expect(instance.state_changed?).to eq(true)
        end

        it 'should log the change' do
          expect(logger).to receive(:debug).with("state_changed? instance state is 'detached'")
          instance.state_changed?
        end
      end

      describe 'when the state is started and the job state is not eq to runnning' do
        let(:state) { 'started' }

        before do
          current_state['job_state'] = 'resting'
        end

        it 'should return true' do
          expect(instance.state_changed?).to eq(true)
        end
        it 'should log the change' do
          expect(logger).to receive(:debug).with("state_changed? instance state is 'started' and job_state is 'resting'")
          instance.state_changed?
        end
      end

      describe 'when the state is stopped and the job state is eq to runnning' do
        let(:state) { 'stopped' }
        before do
          current_state['job_state'] = 'running'
        end

        it 'should return true' do
          expect(instance.state_changed?).to eq(true)
        end

        it 'should log the change' do
          expect(logger).to receive(:debug).with("state_changed? instance state is 'stopped' and job_state is 'running'")
          instance.state_changed?
        end
      end
    end

    describe '#persistent_disk_changed?' do
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment) }

      before { allow(instance_model).to receive(:uuid).and_return('123') }

      let(:disk_pool) do
        Bosh::Director::DeploymentPlan::DiskPool.parse(
          {
            'name' => 'fake-name',
            'disk_size' => disk_size,
            'cloud_properties' => {'type' => 'fake-type'},
          }
        )
      end

      before { instance.bind_existing_instance_model(instance_model) }

      context 'changed' do
        let(:disk_size) { 42 }
        it 'should return true' do
          expect(instance.persistent_disk_changed?).to be(true)
        end

        it 'should log' do
          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: disk size: 0 TO: disk size: 42')
          instance.persistent_disk_changed?
        end
      end

      context 'when disk pool size is greater than 0 and disk properties changed' do
        let(:disk_size) { 42 }
        let(:persistent_disk) { Bosh::Director::Models::PersistentDisk.make(active: true, size: disk_size, cloud_properties: {'old' => 'properties'}) }
        before do
          instance_model.add_persistent_disk(persistent_disk)
        end

        it 'should log the disk properties change' do
          expect(logger).to receive(:debug).with('persistent_disk_changed? changed FROM: {"old"=>"properties"} TO: {"type"=>"fake-type"}')
          instance.persistent_disk_changed?
        end
      end

      context 'when disk pool with size 0 is used' do
        let(:disk_size) { 0 }

        context 'when disk_size is still 0' do
          it 'returns false' do
            expect(instance.persistent_disk_changed?).to be(false)
          end
        end
      end
    end

    describe '#template_spec' do
      let(:job_spec) { {name: 'job', release: 'release', templates: []} }
      let(:release_spec) { {name: 'release', version: '1.1-dev'} }
      let(:resource_pool_spec) { {'name' => 'default', 'stemcell' => {'name' => 'stemcell-name', 'version' => '1.0'}} }
      let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
      let(:properties) { {'key' => 'value'} }
      let(:reservation) { Bosh::Director::DynamicNetworkReservation.new(instance, network) }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}} }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: resource_pool_spec) }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
      let(:network) { DynamicNetwork.parse(network_spec, [], logger) }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          name: 'fake-job',
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
          link_spec: 'fake-link',
          compilation?: false,
          properties: properties)
      }
      let(:disk_pool) { instance_double('Bosh::Director::DeploymentPlan::DiskPool', disk_size: 0, spec: disk_pool_spec) }
      let(:disk_pool_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {}} }
      let(:index) { 0 }
      before do
        ip_provider.reserve(reservation)
        allow(plan).to receive(:network).and_return(network)
        allow(job).to receive(:instance_state).with(index).and_return('started')
      end

      it 'returns a valid instance template_spec' do
        network_name = network_spec['name']
        instance.add_network_reservation(reservation)
        instance.bind_unallocated_vm
        spec = instance.template_spec
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
        expect(spec['links']).to eq('fake-link')
        expect(spec['id']).to eq('uuid-1')
        expect(spec['availability_zone']).to eq('foo-az')
        expect(spec['bootstrap']).to eq(true)
      end

      it 'does not require persistent_disk_pool' do
        allow(job).to receive(:persistent_disk_pool).and_return(nil)

        spec = instance.template_spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end
    end

    describe '#trusted_certs_changed?' do
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when trusted certs have changed' do
        let(:trusted_certs) { "Trust me. I know what I'm doing." }

        before do
          Bosh::Director::Config.trusted_certs = trusted_certs
        end

        it 'should return true' do
          expect(instance.trusted_certs_changed?).to be(true)
        end

        it 'should log the change reason' do
          expect(logger).to receive(:debug).with('trusted_certs_changed? changed FROM: da39a3ee5e6b4b0d3255bfef95601890afd80709 TO: e88d62015cb4220631fec64c7db420761a50cc6b')
          instance.trusted_certs_changed?
        end
      end

      describe 'when trusted certs have not changed' do
        it 'should return false' do
          expect(instance.trusted_certs_changed?).to be(false)
        end
      end
    end

    describe '#apply_spec' do
      let(:job_spec) { {name: 'job', release: 'release', templates: []} }
      let(:release_spec) { {name: 'release', version: '1.1-dev'} }
      let(:resource_pool_spec) { {'name' => 'default', 'stemcell' => {'name' => 'stemcell-name', 'version' => '1.0'}} }
      let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
      let(:properties) { {'key' => 'value'} }
      let(:reservation) { Bosh::Director::DynamicNetworkReservation.new(instance, network) }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}} }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: resource_pool_spec) }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
      let(:network) { DynamicNetwork.parse(network_spec, [], logger) }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          name: 'fake-job',
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
          link_spec: 'fake-link',
          compilation?: false,
          properties: properties)
      }
      let(:disk_pool) { instance_double('Bosh::Director::DeploymentPlan::DiskPool', disk_size: 0, spec: disk_pool_spec) }
      let(:disk_pool_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {}} }
      let(:index) { 0 }
      before do
        ip_provider.reserve(reservation)
        allow(plan).to receive(:network).and_return(network)
        allow(job).to receive(:instance_state).with(index).and_return('started')
      end

      it 'returns a valid instance apply_spec' do
        network_name = network_spec['name']
        instance.add_network_reservation(reservation)
        instance.bind_unallocated_vm
        spec = instance.apply_spec
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
        expect(spec['configuration_hash']).to be_nil
        expect(spec['dns_domain_name']).to eq(domain_name)
        expect(spec['id']).to eq('uuid-1')
      end

      it 'includes rendered_templates_archive key after rendered templates were archived' do
        instance.rendered_templates_archive =
          Bosh::Director::Core::Templates::RenderedTemplatesArchive.new('fake-blobstore-id', 'fake-sha1')

        expect(instance.apply_spec['rendered_templates_archive']).to eq(
            'blobstore_id' => 'fake-blobstore-id',
            'sha1' => 'fake-sha1',
          )
      end

      it 'does not include rendered_templates_archive key before rendered templates were archived' do
        expect(instance.apply_spec).to_not have_key('rendered_templates_archive')
      end

      it 'does not require persistent_disk_pool' do
        allow(job).to receive(:persistent_disk_pool).and_return(nil)

        spec = instance.apply_spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end
    end

    describe '#dns_changed?' do
      let(:job) { Job.new(plan, logger) }

      describe 'when dns is enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
        end

        describe 'when the dns records have not changed' do
          it 'should return false' do
            expect(instance.dns_changed?).to be(false)
          end
        end
      end

      describe 'when dns is not enabled' do
        before do
          allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(false)
        end

        it 'should return false' do
          expect(instance.dns_changed?).to be(false)
        end
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

    describe '#cloud_properties' do
      context 'when the instance has an availability zone' do
        it 'merges the resource pool cloud properties into the availability zone cloud properties' do
          availability_zone = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
          allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one'})
          allow(resource_pool).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.new(job, index, state, plan, current_state, availability_zone, logger)

          expect(instance.cloud_properties).to eq(
              {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
        end
      end

      context 'when the instance does not have an availability zone' do
        it 'uses just the resource pool cloud properties' do
          allow(resource_pool).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.new(job, index, state, plan, current_state, nil, logger)

          expect(instance.cloud_properties).to eq(
              {'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
        end
      end
    end

    describe '#update_cloud_properties' do
      it 'saves the cloud properties' do
        availability_zone = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
        allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one'})
        allow(resource_pool).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

        instance = Instance.new(job, index, state, plan, current_state, availability_zone, logger)
        instance.bind_existing_instance_model(instance_model)

        instance.update_cloud_properties!

        expect(instance_model.cloud_properties_hash).to eq(
            {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
          )

      end
    end
  end
end
