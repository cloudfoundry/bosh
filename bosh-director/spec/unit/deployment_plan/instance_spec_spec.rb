require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstanceSpec do
    include Support::StemcellHelpers
    subject(:instance_spec) { described_class.create_from_instance_plan(instance_plan)}
    let(:job_spec) { {'name' => 'job', 'release' => 'release', 'templates' => []} }
    let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
    let(:properties) { {'key' => 'value'} }
    let(:network_spec) do
      {'name' => 'default', 'subnets' => [{'cloud_properties' => {'foo' => 'bar'}, 'az' => 'foo-az'}]}
    end
    let(:network) { DynamicNetwork.parse(network_spec, [AvailabilityZone.new('foo-az', {})], logger) }
    let(:job) {
      job = instance_double('Bosh::Director::DeploymentPlan::Job',
        name: 'fake-job',
        spec: job_spec,
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: {"gateway" => "default"},
        vm_type: vm_type,
        vm_extensions: [],
        stemcell: stemcell,
        env: env,
        package_spec: packages,
        persistent_disk_type: disk_pool,
        is_errand?: false,
        link_spec: 'fake-link',
        compilation?: false,
        update_spec: {},
        properties: properties)
    }
    let(:index) { 0 }
    let(:instance) { Instance.create_from_job(job, index, 'started', plan, {}, availability_zone, logger) }
    let(:vm_type) { VmType.new({'name' => 'fake-vm-type'}) }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:stemcell) { make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}) }
    let(:env) { Env.new({'key' => 'value'}) }
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
          name: 'fake-deployment',
          model: deployment,
        })
    end
    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment, bootstrap: true, uuid: 'uuid-1') }
    let(:instance_plan) { InstancePlan.new(existing_instance: nil, desired_instance: DesiredInstance.new(job), instance: instance) }
    let(:disk_pool) { instance_double('Bosh::Director::DeploymentPlan::DiskType', disk_size: 0, spec: disk_pool_spec) }
    let(:disk_pool_spec) { {'name' => 'default', 'disk_size' => 300, 'cloud_properties' => {}} }

    before do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, network)
      reservation.resolve_ip('192.168.0.10')

      instance_plan.network_plans << NetworkPlanner::Plan.new(reservation: reservation)
      instance.bind_existing_instance_model(instance_model)
    end

    describe '#apply_spec' do
      it 'returns a valid instance apply_spec' do
        network_name = network_spec['name']
        spec = instance_spec.as_apply_spec
        expect(spec['deployment']).to eq('fake-deployment')
        expect(spec['name']).to eq('fake-job')
        expect(spec['job']).to eq(job_spec)
        expect(spec['az']).to eq('foo-az')
        expect(spec['index']).to eq(index)
        expect(spec['networks']).to include(network_name)

        expect(spec['networks'][network_name]).to eq({
            'type' => 'dynamic',
            'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
            'default' => ['gateway']
            })

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

      it 'does not require persistent_disk_type' do
        allow(job).to receive(:persistent_disk_type).and_return(nil)

        spec = instance_spec.as_apply_spec
        expect(spec['persistent_disk']).to eq(0)
        expect(spec['persistent_disk_pool']).to eq(nil)
      end
    end

    describe '#template_spec' do
      context 'when job has a manual network' do
        let(:subnet_spec) do
          {
            'range' => '192.168.0.0/24',
            'gateway' => '192.168.0.254',
            'cloud_properties' => {'foo' => 'bar'}
          }
        end
        let(:subnet) { ManualNetworkSubnet.parse(network_spec['name'], subnet_spec, [availability_zone], []) }
        let(:network) { ManualNetwork.new(network_spec['name'], [subnet], logger) }

        it 'returns a valid instance template_spec' do
          network_name = network_spec['name']
          spec = instance_spec.as_template_spec

          expect(spec['deployment']).to eq('fake-deployment')
          expect(spec['name']).to eq('fake-job')
          expect(spec['job']).to eq(job_spec)
          expect(spec['index']).to eq(index)
          expect(spec['networks']).to include(network_name)

          expect(spec['networks'][network_name]).to include({
                'ip' => '192.168.0.10',
                'netmask' => '255.255.255.0',
                'cloud_properties' => {'foo' => 'bar'},
                'dns_record_name' => '0.job.default.fake-deployment.bosh',
                'gateway' => '192.168.0.254'
                })

          expect(spec['persistent_disk']).to eq(0)
          expect(spec['configuration_hash']).to be_nil
          expect(spec['properties']).to eq(properties)
          expect(spec['dns_domain_name']).to eq('bosh')
          expect(spec['links']).to eq('fake-link')
          expect(spec['id']).to eq('uuid-1')
          expect(spec['az']).to eq('foo-az')
          expect(spec['bootstrap']).to eq(true)
          expect(spec['resource_pool']).to eq('fake-vm-type')
          expect(spec['address']).to eq('192.168.0.10')
        end
      end

      context 'when job has dynamic network' do
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
                'dns_record_name' => '0.job.default.fake-deployment.bosh',
                'cloud_properties' => network_spec['subnets'].first['cloud_properties'],
                )

          expect(spec['persistent_disk']).to eq(0)
          expect(spec['configuration_hash']).to be_nil
          expect(spec['properties']).to eq(properties)
          expect(spec['dns_domain_name']).to eq('bosh')
          expect(spec['links']).to eq('fake-link')
          expect(spec['id']).to eq('uuid-1')
          expect(spec['az']).to eq('foo-az')
          expect(spec['bootstrap']).to eq(true)
          expect(spec['resource_pool']).to eq('fake-vm-type')
          expect(spec['address']).to eq('uuid-1.fake-job.default.fake-deployment.bosh')
        end
      end
    end
  end
end
