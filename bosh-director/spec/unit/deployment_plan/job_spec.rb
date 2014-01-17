require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Job do
  subject(:job)    { described_class.parse(plan, spec) }

  let(:deployment) { Bosh::Director::Models::Deployment.make }
  let(:plan)       { instance_double('Bosh::Director::DeploymentPlan::Planner', model: deployment) }
  let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', reserve_capacity: nil) }
  let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network') }
  let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }

  let(:spec) do
    {
      'name' => 'foobar',
      'template' => 'foo',
      'release' => 'appcloud',
      'resource_pool' => 'dea',
      'instances' => 1,
      'networks'  => [{'name' => 'fake-network-name'}],
    }
  end

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

  before do
    allow(release).to receive(:use_template_named).with('foo').and_return(foo_template)
    allow(release).to receive(:use_template_named).with('bar').and_return(bar_template)

    allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)

    allow(plan).to receive(:network).and_return(network)
    allow(plan).to receive(:resource_pool).with('dea').and_return resource_pool
    allow(plan).to receive(:update)
  end

  describe '#bind_properties' do
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
      spec['properties'] = props
      spec['template'] = %w(foo bar)

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
    let(:foo_properties) {
      {
        'db.user' => { 'default' => 'root' },
        'db.password' => {},
        'db.host' => { 'default' => 'localhost' },
        'mem' => { 'default' => 256 },
      }
    }

    it 'supports property mappings' do
      props = {
        'ccdb' => {
          'user' => 'admin',
          'password' => '12321',
          'unused' => 'yada yada'
        },
        'dea' => {
          'max_memory' => 2048
        }
      }

      spec['properties'] = props
      spec['property_mappings'] = {'db' => 'ccdb', 'mem' => 'dea.max_memory'}
      spec['template'] = 'foo'

      allow(plan).to receive(:properties).and_return(props)
      expect(plan).to receive(:release).with('appcloud').and_return(release)

      expect(release).to receive(:use_template_named).with('foo').and_return(foo_template)

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
            { 'name' => 'bar', 'release' => 'bar_release' },
          ],
          'resource_pool' => 'dea',
          'instances' => 1,
          'networks' => [{'name' => 'fake-network-name'}],
        }
      end

      before { allow(plan).to receive(:releases).with(no_args).and_return([release, bar_release]) }

      before { allow(plan).to receive(:release).with('bar_release').and_return(bar_release) }
      let(:bar_release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }

      before { allow(bar_release).to receive(:use_template_named).with('bar').and_return(bar_template) }
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
            "Colocated package `same-name' has the same name in multiple releases. " +
            "BOSH cannot currently colocate two packages with identical names from separate releases.",
          )
        end
      end
    end
  end
end
