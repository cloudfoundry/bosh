require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Job do
  subject(:job)    { Bosh::Director::DeploymentPlan::Job.parse(plan, spec, event_log, logger) }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log', warn_deprecated: nil) }

  let(:deployment) { Bosh::Director::Models::Deployment.make }
  let(:fake_ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProviderV2, reserve: nil, reserve_existing_ips: nil) }
  let(:plan) do
    instance_double('Bosh::Director::DeploymentPlan::Planner',
      model: deployment,
      name: 'fake-deployment',
      ip_provider: fake_ip_provider,
    )
  end
  let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }
  let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network') }

  let(:foo_properties) do
    {
      'dea_min_memory' => {'default' => 512},
      'deep_property.dont_override' => {'default' => 'ghi'},
      'deep_property.new_property' => {'default' => 'jkl'}
    }
  end

  let(:bar_properties) do
    {'dea_max_memory' => {'default' => 2048}}
  end

  let(:foo_template) { instance_double(
    'Bosh::Director::DeploymentPlan::Template',
    name: 'foo',
    release: release,
    properties: foo_properties,
  ) }

  let(:bar_template) { instance_double(
    'Bosh::Director::DeploymentPlan::Template',
    name: 'bar',
    release: release,
    properties: bar_properties,
  ) }

  let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
  let(:logger) { double(:logger).as_null_object }
  before do
    allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)

    allow(plan).to receive(:network).and_return(network)
    allow(plan).to receive(:resource_pool).with('dea').and_return resource_pool
    allow(plan).to receive(:update)

    allow(release).to receive(:get_or_create_template).with('foo').and_return(foo_template)
    allow(release).to receive(:get_or_create_template).with('bar').and_return(bar_template)
  end

  describe '#bind_properties' do
    let(:spec) do
      {
        'name' => 'foobar',
        'template' => 'foo',
        'release' => 'appcloud',
        'resource_pool' => 'dea',
        'instances' => 1,
        'networks'  => [{'name' => 'fake-network-name'}],
        'properties' => props,
        'template' => %w(foo bar),
      }
    end

    let(:props) do
      {
        'cc_url' => 'www.cc.com',
        'deep_property' => {
          'unneeded' => 'abc',
          'dont_override' => 'def'
        },
        'dea_max_memory' => 1024
      }
    end

    before do
      allow(plan).to receive(:properties).and_return(props)
      allow(plan).to receive(:release).with('appcloud').and_return(release)
    end

    context 'when all the templates specify properties' do
      it 'should drop deployment manifest properties not specified in the job spec properties' do
        job.bind_properties
        expect(job.properties).to_not have_key('cc')
        expect(job.properties['deep_property']).to_not have_key('unneeded')
      end

      it 'should include properties that are in the job spec properties but not in the deployment manifest' do
        job.bind_properties
        expect(job.properties['dea_min_memory']).to eq(512)
        expect(job.properties['deep_property']['new_property']).to eq('jkl')
      end

      it 'should not override deployment manifest properties with job_template defaults' do
        job.bind_properties
        expect(job.properties['dea_max_memory']).to eq(1024)
        expect(job.properties['deep_property']['dont_override']).to eq('def')
      end
    end

    context 'when none of the job specs (aka templates) specify properties' do
      let(:foo_properties) { nil }
      let(:bar_properties) { nil }

      it 'should use the properties specified throughout the deployment manifest' do
        job.bind_properties
        expect(job.properties).to eq(props)
      end
    end

    context "when some job specs (aka templates) specify properties and some don't" do
      let(:foo_properties) { nil }

      it 'should raise an error' do
        expect {
          job.bind_properties
        }.to raise_error(
          Bosh::Director::JobIncompatibleSpecs,
          "Job `foobar' has specs with conflicting property definition styles" +
          ' between its job spec templates.  This may occur if colocating jobs, one of which has a spec file' +
          " including `properties' and one which doesn't."
        )
      end
    end
  end

  describe 'property mappings' do
    let(:foo_properties) do
      {
        'db.user' => {'default' => 'root'},
        'db.password' => {},
        'db.host' => {'default' => 'localhost'},
        'mem' => {'default' => 256},
      }
    end

    let(:props) do
      {
        'ccdb' => {
          'user' => 'admin',
          'password' => '12321',
          'unused' => 'yada yada'
        },
        'dea' => {
          'max_memory' => 2048
        }
      }
    end

    let(:spec) do
      {
        'name' => 'foobar',
        'template' => 'foo',
        'release' => 'appcloud',
        'resource_pool' => 'dea',
        'instances' => 1,
        'networks' => [{'name' => 'fake-network-name'}],
        'properties' => props,
        'property_mappings' => {'db' => 'ccdb', 'mem' => 'dea.max_memory'},
        'template' => 'foo',
      }
    end

    it 'supports property mappings' do
      allow(plan).to receive(:properties).and_return(props)
      expect(plan).to receive(:release).with('appcloud').and_return(release)

      job.bind_properties

      expect(job.properties).to eq(
                                  'db' => {
                                    'user' => 'admin',
                                    'password' => '12321',
                                    'host' => 'localhost'
                                  },
                                  'mem' => 2048,
                                )
    end
  end

  describe '#validate_package_names_do_not_collide!' do
    let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'release1') }
    before { allow(plan).to receive(:properties).and_return({}) }

    before { allow(foo_template).to receive(:model).and_return(foo_template_model) }
    let(:foo_template_model) { instance_double('Bosh::Director::Models::Template') }

    before { allow(bar_template).to receive(:model).and_return(bar_template_model) }
    let(:bar_template_model) { instance_double('Bosh::Director::Models::Template') }

    before { allow(plan).to receive(:release).with('release1').and_return(release) }

    context 'when the templates are from the same release' do
      let(:spec) do
        {
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'release1' },
          ],
          'resource_pool' => 'dea',
          'instances' => 1,
          'networks' => [{ 'name' => 'fake-network-name' }],
        }
      end

      context 'when templates depend on packages with the same name (i.e. same package)' do
        before { allow(foo_template_model).to receive(:package_names).and_return(['same-name']) }
        before { allow(bar_template_model).to receive(:package_names).and_return(['same-name']) }

        before { allow(plan).to receive(:releases).with(no_args).and_return([release]) }

        it 'does not raise an error' do
          expect { job.validate_package_names_do_not_collide! }.to_not raise_error
        end
      end
    end

    context 'when the templates are from different releases' do
      let(:spec) do
        {
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'bar_release', 'links' => {'a' => 'x.y.z.zz'}},
          ],
          'resource_pool' => 'dea',
          'instances' => 1,
          'networks' => [{'name' => 'fake-network-name'}],
        }
      end

      before { allow(plan).to receive(:releases).with(no_args).and_return([release, bar_release]) }

      before { allow(plan).to receive(:release).with('bar_release').and_return(bar_release) }
      let(:bar_release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'bar_release') }

      before { allow(bar_release).to receive(:get_or_create_template).with('bar').and_return(bar_template) }
      let(:bar_template) do
        instance_double('Bosh::Director::DeploymentPlan::Template', {
          name: 'bar',
          release: bar_release,
        })
      end

      context 'when templates do not depend on packages with the same name' do
        before { allow(foo_template_model).to receive(:package_names).and_return(['one-name']) }
        before { allow(bar_template_model).to receive(:package_names).and_return(['another-name']) }

        it 'does not raise an exception' do
          expect { job.validate_package_names_do_not_collide! }.to_not raise_error
        end
      end

      context 'when templates depend on packages with the same name' do
        before { allow(foo_template_model).to receive(:package_names).and_return(['same-name']) }
        before { allow(bar_template_model).to receive(:package_names).and_return(['same-name']) }

        it 'raises an exception because agent currently cannot collocate similarly named packages from multiple releases' do
          expect {
            job.validate_package_names_do_not_collide!
          }.to raise_error(
            Bosh::Director::JobPackageCollision,
            "Package name collision detected in job `foobar': template `release1/foo' depends on package `release1/same-name',"\
            " template `bar_release/bar' depends on `bar_release/same-name'. " +
              'BOSH cannot currently collocate two packages with identical names from separate releases.',
          )
        end
      end
    end
  end

  describe '#spec' do
    let(:spec) do
      {
        'name' => 'job1',
        'template' => 'foo',
        'release' => 'release1',
        'instances' => 1,
        'resource_pool' => 'dea',
        'networks'  => [{'name' => 'fake-network-name'}],
      }
    end

    before do
      allow(release).to receive(:name).and_return('cf')

      allow(foo_template).to receive(:version).and_return('200')
      allow(foo_template).to receive(:sha1).and_return('fake_sha1')
      allow(foo_template).to receive(:blobstore_id).and_return('blobstore_id_for_foo_template')

      allow(plan).to receive(:releases).with(no_args).and_return([release])
      allow(plan).to receive(:release).with('release1').and_return(release)
      allow(plan).to receive(:properties).with(no_args).and_return({})
    end

    context "when a template has 'logs'" do
      before do
        allow(foo_template).to receive(:logs).and_return(
          {
            'filter_name1' => 'foo/*',
          }
        )
      end

      it 'contains name, release for the job, and logs spec for each template' do
        expect(job.spec).to eq(
          {
            'name' => 'job1',
            'templates' => [
              {
                'name' => 'foo',
                'version' => '200',
                'sha1' => 'fake_sha1',
                'blobstore_id' => 'blobstore_id_for_foo_template',
                'logs' => {
                  'filter_name1' => 'foo/*',
                },
              },
            ],
            'template' => 'foo',
            'version' => '200',
            'sha1' => 'fake_sha1',
            'blobstore_id' => 'blobstore_id_for_foo_template',
            'logs' => {
              'filter_name1' => 'foo/*',
            }
          }
        )
      end
    end

    context "when a template does not have 'logs'" do
      before do
        allow(foo_template).to receive(:logs)
      end

      it 'contains name, release and information for each template' do
        expect(job.spec).to eq(
          {
            'name' => 'job1',
            'templates' =>[
              {
                'name' => 'foo',
                'version' => '200',
                'sha1' => 'fake_sha1',
                'blobstore_id' => 'blobstore_id_for_foo_template',
              },
            ],
            'template' => 'foo',
            'version' => '200',
            'sha1' => 'fake_sha1',
            'blobstore_id' => 'blobstore_id_for_foo_template',
          },
        )
      end
    end
  end

  describe '#bind_unallocated_vms' do
    subject(:job) { described_class.new(deployment, logger) }

    it 'allocates a VM to all non obsolete instances if they are not already bound to a VM' do
      instance0 = instance_double('Bosh::Director::DeploymentPlan::Instance')
      instance1 = instance_double('Bosh::Director::DeploymentPlan::Instance')
      instance_plan0 = Bosh::Director::DeploymentPlan::InstancePlan.new({desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance), existing_instance: nil, instance: instance0})
      instance_plan1 = Bosh::Director::DeploymentPlan::InstancePlan.new({desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance), existing_instance: nil, instance: instance1})
      obsolete_plan = Bosh::Director::DeploymentPlan::InstancePlan.new({desired_instance: nil, existing_instance: nil, instance: instance1})

      job.instance_plans = [instance_plan0, instance_plan1, obsolete_plan]

      [instance0, instance1].each do |instance|
        expect(instance).to receive(:ensure_vm_allocated).with(no_args).ordered
        expect(instance).to receive(:sync_state_with_db).with(no_args).ordered
      end

      job.bind_unallocated_vms
    end
  end

  describe '#bind_instances' do
    subject(:job) { described_class.new(plan, logger) }

    it 'makes sure theres a model, binds unallocated vms, and binds instance networks' do
      instance0 = instance_double('Bosh::Director::DeploymentPlan::Instance')
      instance0_reservation = instance_double(Bosh::Director::DesiredNetworkReservation, reserved?: false)
      instance0_obsolete_reservation = instance_double(Bosh::Director::DesiredNetworkReservation, reserved?: false)
      instance1 = instance_double('Bosh::Director::DeploymentPlan::Instance')
      instance1_reservation = instance_double(Bosh::Director::DesiredNetworkReservation, reserved?: false)
      instance1_existing_reservation = instance_double(Bosh::Director::ExistingNetworkReservation)
      instance_plan0 = Bosh::Director::DeploymentPlan::InstancePlan.new({
          desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance),
          existing_instance: nil,
          instance: instance0,
        })
      instance_plan1 = Bosh::Director::DeploymentPlan::InstancePlan.new({
          desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance),
          existing_instance: nil,
          instance: instance1,
        })
      instance_plan0.network_plans = [
        BD::DeploymentPlan::NetworkPlan.new(reservation: instance0_reservation),
        BD::DeploymentPlan::NetworkPlan.new(reservation: instance0_obsolete_reservation, obsolete: true),
      ]
      instance_plan1.network_plans = [
        BD::DeploymentPlan::NetworkPlan.new(reservation: instance1_reservation),
        BD::DeploymentPlan::NetworkPlan.new(reservation: instance1_existing_reservation),
      ]

      obsolete_plan = Bosh::Director::DeploymentPlan::InstancePlan.new({desired_instance: nil, existing_instance: nil, instance: instance1})

      job.instance_plans = [instance_plan0, instance_plan1, obsolete_plan]

      [instance0, instance1].each do |instance|
        expect(instance).to receive(:ensure_model_bound).with(no_args).ordered
      end
      [instance0, instance1].each do |instance|
        expect(instance).to receive(:ensure_vm_allocated).with(no_args).ordered
        expect(instance).to receive(:sync_state_with_db).with(no_args).ordered
      end

      job.bind_instances

      expect(fake_ip_provider).to have_received(:reserve).with(instance0_reservation)
      expect(fake_ip_provider).to have_received(:reserve).with(instance1_reservation)
      expect(fake_ip_provider).to_not have_received(:reserve).with(instance0_obsolete_reservation)
      expect(fake_ip_provider).to_not have_received(:reserve_existing_ips).with(instance1_existing_reservation)
    end
  end

  describe '#starts_on_deploy?' do
    subject { described_class.new(plan, logger) }

    context "when lifecycle profile is 'service'" do
      before { subject.lifecycle = 'service' }
      its(:starts_on_deploy?) { should be(true) }
    end

    context "when lifecycle profile is not service" do
      before { subject.lifecycle = 'other' }
      its(:starts_on_deploy?) { should be(false) }
    end
  end

  describe '#can_run_as_errand?' do
    subject { described_class.new(plan, logger) }

    context "when lifecycle profile is 'errand'" do
      before { subject.lifecycle = 'errand' }
      its(:can_run_as_errand?) { should be(true) }
    end

    context "when lifecycle profile is not errand" do
      before { subject.lifecycle = 'other' }
      its(:can_run_as_errand?) { should be(false) }
    end
  end
end
