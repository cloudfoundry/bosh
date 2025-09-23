require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstanceSpec do
    include Support::StemcellHelpers
    subject(:instance_spec) { described_class.create_from_instance_plan(instance_plan) }
    let(:links_manager) do
      instance_double(Bosh::Director::Links::LinksManager).tap do |double|
        allow(double).to receive(:get_links_from_deployment).and_return([])
      end
    end
    let(:job_spec) do
      { 'name' => 'smurf-job', 'release' => 'release', 'templates' => [] }
    end
    let(:packages) do
      { 'pkg' => { 'name' => 'package', 'version' => '1.0' } }
    end
    let(:properties) do
      { 'key' => 'value' }
    end
    let(:links) do
      {
        'smurf-job' => {
          'link_name' => {
            'deployment_name' => 'dep1',
            'networks' => ['default'],
            'properties' => {
              'listen_port' => 'Kittens',
            },
            'address' => 'some.address.com',
            'instances' => [
              {
                'name' => 'provider',
                'index' => 0,
                'bootstrap' => true,
                'id' => '3d46803d-1527-4209-8e1f-822105fece7c',
                'az' => 'z1',
                'address' => '10.244.0.4',
              },
            ],
            'instance_group' => 'smurf-ig',
            'default_network' => 'smurf-net',
            'domain' => 'smurf.bosh',
            'use_short_dns_addresses' => true,
            'use_link_dns_names' => true,
            'non-whitelisted-key' => 'some_value',
            'group_name' => 'link_provider_name-link_provider_type',
          },
        },
      }
    end
    let(:smurf_job_links) { links['smurf-job'] }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    let(:lifecycle) { InstanceGroup::DEFAULT_LIFECYCLE_PROFILE }
    let(:network_spec) do
      { 'name' => 'default', 'subnets' => [{ 'cloud_properties' => { 'foo' => 'bar' }, 'az' => 'foo-az' }] }
    end
    let(:network) { DynamicNetwork.parse(network_spec, [AvailabilityZone.new('foo-az', {})], per_spec_logger) }
    let(:instance_group) do
      instance_double(
        'Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'fake-job',
        spec: job_spec,
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: { 'gateway' => 'default' },
        vm_type: vm_type,
        vm_extensions: [],
        stemcell: stemcell,
        env: env,
        package_spec: packages,
        persistent_disk_collection: persistent_disk_collection,
        errand?: false,
        compilation?: false,
        update_spec: {},
        properties: properties,
        lifecycle: lifecycle,
        vm_resources: nil,
        vm_strategy: UpdateConfig::VM_STRATEGY_DELETE_CREATE,
      )
    end
    let(:index) { 0 }
    let(:instance_state) do
      {}
    end
    let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:instance) do
      instance = Instance.create_from_instance_group(
        instance_group,
        index,
        'started',
        deployment,
        instance_state,
        availability_zone,
        per_spec_logger,
        variables_interpolator,
      )
      instance.desired_variable_set = desired_variable_set
      instance
    end
    let(:vm_type) { VmType.new('name' => 'fake-vm-type') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', 'a' => 'b') }
    let(:stemcell) { make_stemcell(name: 'fake-stemcell-name', version: '1.0') }
    let(:env) { Env.new('key' => 'value') }
    let(:deployment_name) { 'fake-deployment' }
    let(:deployment) { FactoryBot.create(:models_deployment, name: deployment_name) }
    let(:instance_model) { FactoryBot.create(:models_instance, deployment: deployment, bootstrap: true, uuid: 'uuid-1') }
    let(:instance_plan) do
      InstancePlan.new(
        existing_instance: nil,
        desired_instance: DesiredInstance.new(instance_group),
        instance: instance,
        variables_interpolator: variables_interpolator,
      )
    end
    let(:persistent_disk_collection) { PersistentDiskCollection.new(per_spec_logger) }

    before do
      allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)

      persistent_disk_collection.add_by_disk_size(0)

      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, network)
      reservation.resolve_ip('192.168.0.10')

      instance_plan.network_plans << NetworkPlanner::Plan.new(reservation: reservation)
      instance.bind_existing_instance_model(instance_model)
    end

    describe '#as_apply_spec' do
      it 'returns a valid instance apply_spec' do
        network_name = network_spec['name']
        spec = instance_spec.as_apply_spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['name']).to eq('fake-job')
        expect(spec['job']).to eq(job_spec)
        expect(spec['az']).to eq('foo-az')
        expect(spec['index']).to eq(index)
        expect(spec['networks']).to include(network_name)

        expect(spec['networks'][network_name]).to eq(
          'type' => 'dynamic',
          'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
          'default' => ['gateway'],
        )

        expect(spec['packages']).to eq(packages)
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['configuration_hash']).to be_nil
        expect(spec['dns_domain_name']).to eq('bosh')
        expect(spec['id']).to eq('uuid-1')
      end

      it 'includes rendered_templates_archive key after rendered templates were archived' do
        instance.rendered_templates_archive =
          Bosh::Director::Core::Templates::RenderedTemplatesArchive.new('fake-blobstore-id', 'fake-sha1')

        expect(instance_spec.as_apply_spec['rendered_templates_archive']).to eq(
          'blobstore_id' => 'fake-blobstore-id',
          'sha1' => 'fake-sha1',
        )
      end

      it 'does not include rendered_templates_archive key before rendered templates were archived' do
        expect(instance_spec.as_apply_spec).to_not have_key('rendered_templates_archive')
      end
    end

    describe '#as_jobless_apply_spec' do
      it 'returns a valid instance apply_spec' do
        network_name = network_spec['name']
        spec = instance_spec.as_jobless_apply_spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['name']).to eq('fake-job')
        expect(spec['job']).to eq({})
        expect(spec['az']).to eq('foo-az')
        expect(spec['index']) .to eq(index)
        expect(spec['networks']).to include(network_name)

        expect(spec['networks'][network_name]).to eq(
          'type' => 'dynamic',
          'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
          'default' => ['gateway'],
        )

        expect(spec['packages']).to eq(packages)
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['configuration_hash']).to be_nil
        expect(spec['dns_domain_name']).to eq('bosh')
        expect(spec['id']).to eq('uuid-1')
      end

      it 'includes rendered_templates_archive key after rendered templates were archived' do
        instance.rendered_templates_archive =
          Bosh::Director::Core::Templates::RenderedTemplatesArchive.new('fake-blobstore-id', 'fake-sha1')

        expect(instance_spec.as_jobless_apply_spec['rendered_templates_archive']).to eq(
          'blobstore_id' => 'fake-blobstore-id',
          'sha1' => 'fake-sha1',
        )
      end

      it 'does not include rendered_templates_archive key before rendered templates were archived' do
        expect(instance_spec.as_jobless_apply_spec).to_not have_key('rendered_templates_archive')
      end
    end

    describe '#template_spec' do
      let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:expected_links) do
        {
          'smurf-job' => {
            'link_name' => {
              'properties' => {
                'listen_port' => 'Kittens',
              },
              'address' => 'some.address.com',
              'instances' => [{
                'name' => 'provider',
                'index' => 0,
                'bootstrap' => true,
                'id' => '3d46803d-1527-4209-8e1f-822105fece7c',
                'az' => 'z1',
                'address' => '10.244.0.4',
              }],
              'instance_group' => 'smurf-ig',
              'default_network' => 'smurf-net',
              'deployment_name' => 'dep1',
              'domain' => 'smurf.bosh',
              'use_short_dns_addresses' => true,
              'use_link_dns_names' => true,
              'group_name' => 'link_provider_name-link_provider_type',
            },
          },
        }
      end

      before do
        allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        allow(variables_interpolator).to receive(:interpolate_template_spec_properties)
          .with(properties, 'fake-deployment', instance.instance_group_name, instance.desired_variable_set)
          .and_return(properties)
        allow(variables_interpolator).to receive(:interpolate_link_spec_properties)
          .with(smurf_job_links, instance.desired_variable_set)
          .and_return(smurf_job_links)

        expect(links_manager).to receive(:get_links_for_instance).and_return(links)
      end

      context 'links specs whitelisting' do
        it 'respects whitelist for links spec' do
          expect([instance_spec.as_template_spec['links']]).to include(expected_links)
        end
      end

      context 'properties interpolation' do
        let(:properties) do
          {
            'smurf_1' => '((smurf_placeholder_1))',
            'smurf_2' => '((smurf_placeholder_2))',
          }
        end

        let(:first_link) do
          {
            'deployment_name' => 'dep1',
            'instances' => [{ 'name' => 'v1' }],
            'networks' => 'foo',
            'properties' => { 'smurf' => '((smurf_val1))' },
          }
        end

        let(:second_link) do
          {
            'deployment_name' => 'dep2',
            'instances' => [{ 'name' => 'v2' }],
            'networks' => 'foo2',
            'properties' => { 'smurf' => '((smurf_val2))' },
          }
        end

        let(:links) do
          {
            'smurf-job' => {
              'link_1' => first_link,
              'link_2' => second_link,
            },
          }
        end

        let(:resolved_properties) do
          {
            'smurf_1' => 'lazy smurf',
            'smurf_2' => 'happy smurf',
          }
        end

        let(:resolved_first_link) do
          { 'instances' => [{ 'name' => 'v1' }], 'properties' => { 'smurf' => 'strong smurf' } }
        end

        let(:resolved_second_link) do
          { 'instances' => [{ 'name' => 'v2' }], 'properties' => { 'smurf' => 'sleepy smurf' } }
        end

        let(:resolved_links) do
          {
            'smurf-job' => {
              'link_1' => resolved_first_link,
              'link_2' => resolved_second_link,
            },
          }
        end

        let(:resolved_smurf_job_links) { resolved_links['smurf-job'] }

        it 'resolves properties and links properties' do
          expect(variables_interpolator).to receive(:interpolate_template_spec_properties)
            .with(properties, 'fake-deployment', instance.instance_group_name, instance.desired_variable_set)
            .and_return(resolved_properties)
          expect(variables_interpolator).to receive(:interpolate_link_spec_properties)
            .with(smurf_job_links, instance.desired_variable_set)
            .and_return(resolved_smurf_job_links)

          spec = instance_spec.as_template_spec
          expect(spec['properties']).to eq(resolved_properties)
          expect(spec['links']).to eq(resolved_links)
        end
      end

      context 'when instance_group has a manual network' do
        let(:subnet_spec) do
          {
            'range' => '192.168.0.0/24',
            'gateway' => '192.168.0.254',
            'cloud_properties' => { 'foo' => 'bar' },
          }
        end
        let(:subnet) { ManualNetworkSubnet.parse(network_spec['name'], subnet_spec, [availability_zone]) }
        let(:network) { ManualNetwork.new(network_spec['name'], [subnet], nil, per_spec_logger) }

        it 'returns a valid instance template_spec' do
          network_name = network_spec['name']
          spec = instance_spec.as_template_spec

          expect(spec['deployment']).to eq('fake-deployment')
          expect(spec['name']).to eq('fake-job')
          expect(spec['job']).to eq(job_spec)
          expect(spec['index']).to eq(index)
          expect(spec['networks']).to include(network_name)

          expect(spec['networks'][network_name]).to include(
            'ip' => '192.168.0.10',
            'netmask' => '255.255.255.0',
            'cloud_properties' => { 'foo' => 'bar' },
            'dns_record_name' => '0.smurf-job.default.fake-deployment.bosh',
            'gateway' => '192.168.0.254',
          )

          expect(spec['persistent_disk']).to eq(0)
          expect(spec['configuration_hash']).to be_nil
          expect(spec['properties']).to eq(properties)
          expect(spec['dns_domain_name']).to eq('bosh')
          expect(spec['links']).to eq(expected_links)
          expect(spec['id']).to eq('uuid-1')
          expect(spec['az']).to eq('foo-az')
          expect(spec['bootstrap']).to eq(true)
          expect(spec['address']).to eq('192.168.0.10')
          expect(spec['ip']).to eq('192.168.0.10')
        end
      end

      context 'when instance_group has dynamic network' do
        context 'when vm does not have network ip assigned' do
          it 'returns a valid instance template_spec' do
            network_name = network_spec['name']
            spec = instance_spec.as_template_spec
            expect(spec['deployment']).to eq('fake-deployment')
            expect(spec['name']).to eq('fake-job')
            expect(spec['job']).to eq(job_spec)
            expect(spec['index']).to eq(index)
            expect(spec['networks']).to include(network_name)

            expect(spec['networks'][network_name]).to include(
              'type' => 'dynamic',
              'ip' => '127.0.0.1',
              'netmask' => '127.0.0.1',
              'gateway' => '127.0.0.1',
              'dns_record_name' => '0.smurf-job.default.fake-deployment.bosh',
              'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
            )

            expect(spec['persistent_disk']).to eq(0)
            expect(spec['configuration_hash']).to be_nil
            expect(spec['properties']).to eq(properties)
            expect(spec['dns_domain_name']).to eq('bosh')
            expect(spec['links']).to eq(expected_links)
            expect(spec['id']).to eq('uuid-1')
            expect(spec['az']).to eq('foo-az')
            expect(spec['bootstrap']).to eq(true)
            expect(spec['address']).to eq('uuid-1.fake-job.default.fake-deployment.bosh')
            expect(spec['ip']).to eq(nil)
          end
        end
        context 'when vm has network ip assigned' do
          let(:instance_state) do
            {
              'networks' => {
                'default' => {
                  'type' => 'dynamic',
                  'ip' => '192.0.2.19',
                  'netmask' => '255.255.255.0',
                  'gateway' => '192.0.2.1',
                },
              },
            }
          end

          it 'returns a valid instance template_spec' do
            network_name = network_spec['name']
            spec = instance_spec.as_template_spec
            expect(spec['deployment']).to eq('fake-deployment')
            expect(spec['name']).to eq('fake-job')
            expect(spec['job']).to eq(job_spec)
            expect(spec['index']).to eq(index)
            expect(spec['networks']).to include(network_name)

            expect(spec['networks'][network_name]).to include(
              'type' => 'dynamic',
              'ip' => '192.0.2.19',
              'netmask' => '255.255.255.0',
              'gateway' => '192.0.2.1',
              'dns_record_name' => '0.smurf-job.default.fake-deployment.bosh',
              'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
            )

            expect(spec['persistent_disk']).to eq(0)
            expect(spec['configuration_hash']).to be_nil
            expect(spec['properties']).to eq(properties)
            expect(spec['dns_domain_name']).to eq('bosh')
            expect(spec['links']).to eq(expected_links)
            expect(spec['id']).to eq('uuid-1')
            expect(spec['az']).to eq('foo-az')
            expect(spec['bootstrap']).to eq(true)
            expect(spec['address']).to eq('uuid-1.fake-job.default.fake-deployment.bosh')
            expect(spec['ip']).to eq('192.0.2.19')
          end
        end
      end
    end

    describe '#full_spec' do
      it 'return correct json format' do
        expected_spec = {
          'deployment' => 'fake-deployment',
          'job' => {
            'name' => 'smurf-job',
            'release' => 'release',
            'templates' => [],
          },
          'index' => 0,
          'bootstrap' => true,
          'lifecycle' => 'service',
          'name' => 'fake-job',
          'id' => 'uuid-1',
          'az' => 'foo-az',
          'networks' => {
            'default' => {
              'type' => 'dynamic',
              'cloud_properties' => { 'foo' => 'bar' },
              'default' => ['gateway'],
            },
          },
          'vm_type' => {
            'name' => 'fake-vm-type',
            'cloud_properties' => {},
          },
          'vm_resources' => nil,
          'stemcell' => {
            'name' => 'fake-stemcell-name',
            'version' => '1.0',
          },
          'env' => { 'key' => 'value' },
          'packages' => {
            'pkg' => {
              'name' => 'package',
              'version' => '1.0',
            },
          },
          'properties' => { 'key' => 'value' },
          'properties_need_filtering' => true,
          'dns_domain_name' => 'bosh',
          'address' => 'uuid-1.fake-job.default.fake-deployment.bosh',
          'update' => {},
          'persistent_disk' => 0,
          'persistent_disk_type' => {
            'name' => String,
            'disk_size' => 0,
            'cloud_properties' => {},
          },
        }
        expect(instance_spec.full_spec).to match(expected_spec)
      end

      context 'when CompilationJobs' do
        let(:lifecycle) { nil }
        context 'lifecycle is not set' do
          it "contains 'nil' for 'lifecycle'" do
            expect(instance_spec.full_spec['lifecycle']).to be_nil
          end
        end
      end

      InstanceGroup::VALID_LIFECYCLE_PROFILES.each do |lifecycle_value|
        context "when 'lifecycle' is set to '#{lifecycle_value}'" do
          let(:lifecycle) { lifecycle_value }

          it "contains '#{lifecycle_value}' for 'lifecycle'" do
            expect(instance_spec.full_spec['lifecycle']).to eq(lifecycle_value)
          end
        end
      end
    end
  end
end
