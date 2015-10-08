require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do
    include Support::StemcellHelpers

    subject(:instance) { Instance.new(job, index, state, plan, current_state, availability_zone, true, logger) }
    let(:index) { 0 }
    let(:state) { 'started' }
    let(:in_memory_ip_repo) { InMemoryIpRepo.new(logger) }
    let(:vip_repo) { VipRepo.new(logger) }
    let(:ip_provider) { IpProviderV2.new(in_memory_ip_repo, vip_repo, false, logger) }

    before { allow(Bosh::Director::Config).to receive(:dns).and_return({'domain_name' => 'test_domain'}) }
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
          recreate: plan_recreate,
          availability_zones: [availability_zone],
          ip_provider: instance_double('Bosh::Director::DeploymentPlan::IpProviderV2', reserve_existing_ips: nil)
        })
    end
    let(:network_resolver) { GlobalNetworkResolver.new(plan) }
    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::Job',
        vm_type: vm_type,
        stemcell: stemcell,
        env: env,
        deployment: plan,
        name: 'fake-job',
        persistent_disk_type: disk_type,
        compilation?: false,
        can_run_as_errand?: false
      )
    end
    let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
    let(:stemcell) { make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}) }
    let(:env) { Env.new({'key' => 'value'}) }
    let(:disk_type) { nil }
    let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:vm) { Vm.new }
    before do
      allow(job).to receive(:instance_state).with(0).and_return('started')
    end

    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment) }
    let(:vm_model) { Bosh::Director::Models::Vm.make }

    let(:current_state) { {'current' => 'state'} }
    let(:desired_instance) { DesiredInstance.new(job, current_state, plan, availability_zone, 1)}

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
        allow(job).to receive(:vm_type).and_return(vm_type)
        allow(job).to receive(:stemcell).and_return(stemcell)
      end

      it 'creates a new VM and binds it the instance' do
        instance.bind_unallocated_vm

        expect(instance.model).not_to be_nil
        expect(instance.vm).not_to be_nil
        expect(instance.vm.bound_instance).to eq(instance)
      end

      it 'creates a new uuid for each instance' do
        allow(SecureRandom).to receive(:uuid).and_return('uuid-1', 'uuid-2')
        first_instance = Instance.new(job, index, state, plan, current_state, availability_zone, false, logger)
        first_instance.bind_unallocated_vm
        first_uuid = first_instance.uuid
        index = 1
        second_instance = Instance.new(job, index, state, plan, current_state, availability_zone, false, logger)
        second_instance.bind_unallocated_vm
        second_uuid = second_instance.uuid
        expect(first_uuid).to_not be_nil
        expect(second_uuid).to_not be_nil
        expect(first_uuid).to_not eq(second_uuid)
      end
    end

    describe '#bind_existing_instance_model' do
      let(:job) { Job.new(plan, logger) }

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

    describe '#bind_new_instance_model' do
      it 'sets the instance model and uuid' do
        expect(instance.model).to be_nil
        expect(instance.uuid).to be_nil

        instance.bind_new_instance_model
        expect(instance.model).not_to be_nil
        expect(instance.uuid).not_to be_nil
      end
    end

    describe '#apply_vm_state' do
      let(:job) { Job.new(plan, logger) }

      before do
        job.templates = [template]
        job.name = 'fake-job'
        job.default_network = {}
        reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance, network, '10.0.0.6')
        network_plans = [NetworkPlan.new(reservation: reservation)]
        desired_instance = DesiredInstance.new
        job.add_instance_plans([InstancePlan.new(existing_instance: nil, desired_instance: desired_instance, instance: instance, network_plans: network_plans)])
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

      let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
      let(:stemcell) { Stemcell.new({'name' => 'fake-stemcell-name', 'version' => '1.0'}) }

      before do
        job.vm_type = vm_type
        job.stemcell = stemcell
      end
      before { allow(job).to receive(:spec).with(no_args).and_return('fake-job-spec') }

      let(:network) do
        instance_double('Bosh::Director::DeploymentPlan::Network', {
            name: 'fake-network',
            network_settings: {'fake-network-settings' => {}},
          })
      end

      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
      before { allow(agent_client).to receive(:apply) }

      before { allow(Bosh::Director::AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client) }

      before { allow(plan).to receive(:network).with('fake-network').and_return(network) }

      before do
        instance.configuration_hash = 'fake-desired-configuration-hash'

        instance.bind_unallocated_vm
        instance.bind_to_vm_model(vm_model)
      end

      context 'when agent returns updated configuration hash' do
        before do
          state = {
            'deployment' => 'fake-deployment',
            'job' => 'fake-job-spec',
            'index' => 0,
            'id' => 'uuid-1',
            'networks' => {'fake-network' => {'fake-network-settings' => {}, 'dns_record_name' => '0.fake-job.fake-network.fake-deployment.test-domain'}},
            'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}},
            'stemcell' => {'name' => 'fake-stemcell-name', 'version' => '1.0'},
            'packages' => {},
            'configuration_hash' => 'fake-desired-configuration-hash',
            'dns_domain_name' => 'test-domain',
            'persistent_disk' => 0
          }

          expect(vm_model).to receive(:update).with(apply_spec: state).ordered
          expect(agent_client).to receive(:apply).with(state).ordered

          returned_state = state.merge('configuration_hash' => 'fake-old-configuration-hash')
          expect(agent_client).to receive(:get_state).and_return(returned_state).ordered
        end

        it 'updates the model with the spec, applies to state to the agent, and sets the current state of the instance' do
          instance.apply_vm_state
          expect(instance.configuration_changed?).to be_truthy
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

    describe '#template_spec' do
      let(:job_spec) { {name: 'job', release: 'release', templates: []} }
      let(:release_spec) { {name: 'release', version: '1.1-dev'} }
      let(:resource_pool_spec) { {'name' => 'default', 'stemcell' => {'name' => 'stemcell-name', 'version' => '1.0'}} }
      let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
      let(:properties) { {'key' => 'value'} }
      let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance, network) }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}, 'availability_zone' => 'foo-az'} }
      let(:vm_type) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: vm_type_spec) }
      let(:vm_type_spec) { {'name' => 'fake-vm-type', 'cloud_properties' => {}} }
      let(:stemcell) { instance_double('Bosh::Director::DeploymentPlan::Stemcell', spec: stemcell_spec) }
      let(:stemcell_spec) { {'name' => 'fake-stemcell-name', 'version' => '1.0'} }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
      let(:network) { DynamicNetwork.parse(network_spec, [AvailabilityZone.new('foo-az', {})], logger) }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          name: 'fake-job',
          deployment: plan,
          spec: job_spec,
          canonical_name: 'job',
          instances: ['instance0'],
          release: release,
          default_network: {},
          vm_type: vm_type,
          stemcell: stemcell,
          env: env,
          package_spec: packages,
          persistent_disk_type: disk_pool,
          can_run_as_errand?: false,
          link_spec: 'fake-link',
          compilation?: false,
          properties: properties)
      }
      let(:disk_pool) { instance_double('Bosh::Director::DeploymentPlan::DiskType', disk_size: 0, spec: disk_pool_spec) }
      let(:disk_pool_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {}} }
      let(:index) { 0 }
      before do
        ip_provider.reserve(reservation)
        allow(plan).to receive(:network).and_return(network)
        allow(job).to receive(:instance_state).with(index).and_return('started')
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(nil, network)
        network_plans = [NetworkPlan.new(reservation: reservation)]
        allow(job).to receive(:needed_instance_plans).and_return([InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance, network_plans: network_plans)])
      end

      it 'returns a valid instance template_spec' do
        network_name = network_spec['name']
        instance.bind_unallocated_vm
        spec = instance.template_spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['job']).to eq(job_spec)
        expect(spec['index']).to eq(index)
        expect(spec['networks']).to include(network_name)

        expect_dns_name = "#{index}.fake-job.#{network_name}.fake-deployment.test-domain"
        expect(spec['networks'][network_name]).to include(
            'type' => 'dynamic',
            'cloud_properties' => network_spec['cloud_properties'],
            'dns_record_name' => expect_dns_name
          )

        expect(spec['vm_type']).to eq(vm_type.spec)
        expect(spec['stemcell']).to eq(stemcell.spec)
        expect(spec['env']).to eq(env.spec)
        expect(spec['packages']).to eq(packages)
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(disk_pool_spec)
        expect(spec['configuration_hash']).to be_nil
        expect(spec['properties']).to eq(properties)
        expect(spec['dns_domain_name']).to eq('test-domain')
        expect(spec['links']).to eq('fake-link')
        expect(spec['id']).to eq('uuid-1')
        expect(spec['availability_zone']).to eq('foo-az')
        expect(spec['bootstrap']).to eq(true)
      end

      it 'does not require persistent_disk_pool' do
        allow(job).to receive(:persistent_disk_type).and_return(nil)

        spec = instance.template_spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end

      context 'when persistent disk type' do
        let(:job) {
          job = instance_double('Bosh::Director::DeploymentPlan::Job',
            name: 'fake-job',
            deployment: plan,
            spec: job_spec,
            canonical_name: 'job',
            instances: ['instance0'],
            release: release,
            default_network: {},
            vm_type: vm_type,
            stemcell: stemcell,
            env: env,
            package_spec: packages,
            persistent_disk_type: disk_type,
            can_run_as_errand?: false,
            link_spec: 'fake-link',
            compilation?: false,
            properties: properties)
        }
        let(:disk_type) { instance_double('Bosh::Director::DeploymentPlan::DiskType', disk_size: 0, spec: disk_type_spec) }
        let(:disk_type_spec) { {'name' => 'default', 'disk_size' => 400, 'cloud_properties' => {}} }

        it 'returns a valid instance template_spec' do
          network_name = network_spec['name']
          instance.bind_unallocated_vm
          spec = instance.template_spec
          expect(spec['deployment']).to eq('fake-deployment')
          expect(spec['job']).to eq(job_spec)
          expect(spec['index']).to eq(index)
          expect(spec['networks']).to include(network_name)

          expect_dns_name = "#{index}.fake-job.#{network_name}.fake-deployment.test-domain"

          expect(spec['networks'][network_name]).to include(
              'type' => 'dynamic',
              'cloud_properties' => network_spec['cloud_properties'],
              'dns_record_name' => expect_dns_name
            )

          expect(spec['vm_type']).to eq(vm_type.spec)
          expect(spec['stemcell']).to eq(stemcell.spec)
          expect(spec['env']).to eq(env.spec)
          expect(spec['packages']).to eq(packages)
          expect(spec['persistent_disk']).to eq(0)
          expect(spec['persistent_disk_type']).to eq(disk_type_spec)
          expect(spec['configuration_hash']).to be_nil
          expect(spec['properties']).to eq(properties)
          expect(spec['dns_domain_name']).to eq('test-domain')
          expect(spec['links']).to eq('fake-link')
          expect(spec['id']).to eq('uuid-1')
          expect(spec['availability_zone']).to eq('foo-az')
          expect(spec['bootstrap']).to eq(true)
        end

        it 'does not require persistent_disk_type' do
          allow(job).to receive(:persistent_disk_type).and_return(nil)

          spec = instance.template_spec
          expect(spec['persistent_disk']).to eq(0)
          expect(spec['persistent_disk_type']).to eq(nil)
        end
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
      let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance, network) }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}, 'availability_zone' => 'foo-az'} }
      let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: resource_pool_spec) }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
      let(:network) { DynamicNetwork.parse(network_spec, [AvailabilityZone.new('foo-az', {})], logger) }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          name: 'fake-job',
          deployment: plan,
          spec: job_spec,
          canonical_name: 'job',
          instances: ['instance0'],
          release: release,
          default_network: {},
          vm_type: vm_type,
          stemcell: stemcell,
          env: env,
          package_spec: packages,
          persistent_disk_type: disk_type,
          can_run_as_errand?: false,
          link_spec: 'fake-link',
          compilation?: false,
          properties: properties)
      }
      let(:disk_type) { instance_double('Bosh::Director::DeploymentPlan::DiskType', disk_size: 0, spec: disk_type_spec) }
      let(:disk_type_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {}} }
      let(:index) { 0 }
      before do
        ip_provider.reserve(reservation)
        allow(plan).to receive(:network).and_return(network)
        allow(job).to receive(:instance_state).with(index).and_return('started')
        reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance, network)
        network_plans = [NetworkPlan.new(reservation: reservation)]
        allow(job).to receive(:needed_instance_plans).and_return [InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance, network_plans: network_plans)]
      end

      it 'returns a valid instance apply_spec' do
        network_name = network_spec['name']
        instance.bind_unallocated_vm
        spec = instance.apply_spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['job']).to eq(job_spec)
        expect(spec['index']).to eq(index)
        expect(spec['networks']).to include(network_name)

        expect_dns_name = "#{index}.fake-job.#{network_name}.fake-deployment.test-domain"
        expect(spec['networks'][network_name]).to include(
            'type' => 'dynamic',
            'cloud_properties' => network_spec['cloud_properties'],
            'dns_record_name' => expect_dns_name
          )

        expect(spec['vm_type']).to eq(vm_type.spec)
        expect(spec['stemcell']).to eq(stemcell.spec)
        expect(spec['env']).to eq(env.spec)
        expect(spec['packages']).to eq(packages)
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['configuration_hash']).to be_nil
        expect(spec['dns_domain_name']).to eq('test-domain')
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

      it 'does not require persistent_disk_type' do
        allow(job).to receive(:persistent_disk_type).and_return(nil)

        spec = instance.apply_spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end
    end

    describe '#cloud_properties_changed?' do
      let(:instance_model) {
        model = Bosh::Director::Models::Instance.make(deployment: deployment)
        model.cloud_properties_hash = {'a' => 'b'}
        model
      }
      let(:job) {
        job = instance_double('Bosh::Director::DeploymentPlan::Job',
          name: 'fake-job',
          vm_type: vm_type,
          stemcell: stemcell,
        )
      }

      before do
        instance.bind_existing_instance_model(instance_model)
      end

      describe 'when neither the resource pool cloud properties, nor the availability zone cloud properties change' do
        it 'should return false' do
          expect(instance.cloud_properties_changed?).to eq(false)
        end
      end

      describe 'when the cloud properties change' do

        describe 'logging' do
          before do
            availability_zone.cloud_properties['baz'] = 'bang'
            vm_type.cloud_properties['abcd'] = 'wera'
          end

          it 'should log the change' do
            expect(logger).to receive(:debug).with('cloud_properties_changed? changed FROM: {"a"=>"b"} TO: {"a"=>"b", "baz"=>"bang", "abcd"=>"wera"}')
            instance.cloud_properties_changed?
          end
        end

        describe 'when the availability zone cloud properties change' do
          before do
            availability_zone.cloud_properties['baz'] = 'bang'
          end

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when the resource pool cloud properties change' do
          before do
            vm_type.cloud_properties['abcd'] = 'wera'
          end

          it 'should return true' do
            expect(instance.cloud_properties_changed?).to eq(true)
          end
        end

        describe 'when there is no availability zone' do
          let(:availability_zone) { nil }
          let(:instance_model) {
            model = Bosh::Director::Models::Instance.make(deployment: deployment)
            model.cloud_properties_hash = {}
            model
          }

          describe 'and resource pool cloud properties has not changed' do
            it 'should return false' do
              expect(instance.cloud_properties_changed?).to be(false)
            end
          end

          describe 'when there is no availability zone and resource pool cloud properties change' do
            before do
              vm_type.cloud_properties['abcd'] = 'wera'
            end

            it 'should return true' do
              expect(instance.cloud_properties_changed?).to be(true)
            end
          end
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
          allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.new(job, index, state, plan, current_state, availability_zone, false, logger)

          expect(instance.cloud_properties).to eq(
              {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            )
        end
      end

      context 'when the instance does not have an availability zone' do
        it 'uses just the resource pool cloud properties' do
          allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

          instance = Instance.new(job, index, state, plan, current_state, nil, false, logger)

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
        allow(vm_type).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

        instance = Instance.new(job, index, state, plan, current_state, availability_zone, false, logger)
        instance.bind_existing_instance_model(instance_model)

        instance.update_cloud_properties!

        expect(instance_model.cloud_properties_hash).to eq(
            {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
          )

      end
    end

    describe '#bind_existing_reservations' do
      before do
        instance.bind_existing_instance_model(instance_model)
      end

      context 'when instance has reservations in db' do
        before do
          ip_address = BD::Models::IpAddress.make(address: 123)
          instance_model.add_ip_address(ip_address)
        end

        it 'is using reservation from database' do
          instance.bind_existing_reservations(nil)
          expect(instance.existing_network_reservations.map(&:ip)).to eq([123])
        end
      end

      context 'when instance does not have reservations in database' do
        context 'when binding reservations with state' do
          it 'creates reservations from state' do
            instance.bind_existing_reservations({'networks' => {'fake-network' => {'ip' => 345}}})
            expect(instance.existing_network_reservations.map(&:ip)).to eq([345])
          end
        end

        context 'when binding without state' do
          it 'has no reservations' do
            instance.bind_existing_reservations(nil)
            expect(instance.existing_network_reservations.map(&:ip)).to eq([])
          end
        end
      end
    end
  end
end
