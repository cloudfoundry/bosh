require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      describe :initialize do
        it 'should parse the manifest' do
          plan = Planner.new(some: :manifest)

          plan.should_receive(:parse_name)
          plan.should_receive(:parse_properties)
          plan.should_receive(:parse_releases)
          plan.should_receive(:parse_networks)
          plan.should_receive(:parse_compilation)
          plan.should_receive(:parse_update)
          plan.should_receive(:parse_resource_pools)
          plan.should_receive(:parse_jobs)

          plan.parse
        end

        describe :options do
          it 'should parse recreate' do
            plan = Planner.new({})
            plan.recreate.should == false

            plan = Planner.new({}, 'recreate' => true)
            plan.recreate.should == true
          end
        end
      end

      describe :parse_name do
        it 'should parse the raw and canonical names' do
          plan = Planner.new({ 'name' => 'Test Deployment' })
          plan.parse_name
          plan.name.should == 'Test Deployment'
          plan.canonical_name.should == 'testdeployment'
        end
      end

      describe :parse_properties do
        it 'should parse basic properties' do
          plan = Planner.new({ 'properties' => { 'foo' => 'bar' } })
          plan.parse_properties
          plan.properties.should == { 'foo' => 'bar' }
        end

        it 'should allow not having any properties' do
          plan = Planner.new({ 'name' => 'Test Deployment' })
          plan.parse_properties
          plan.properties.should == {}
        end
      end

      describe :parse_releases do
        let(:release_spec) do
          {
            'name' => 'foo',
            'version' => '23'
          }
        end

        let(:releases_spec) do
          [
            { 'name' => 'foo', 'version' => '27' },
            { 'name' => 'bar', 'version' => '42' }
          ]
        end

        it 'should create a release spec' do
          plan = Planner.new({ 'release' => release_spec })
          plan.parse_releases
          plan.releases.size.should == 1
          release = plan.releases[0]
          release.should be_kind_of(ReleaseVersion)
          release.name.should == 'foo'
          release.version.should == '23'
          release.spec.should == release_spec

          plan.release('foo').should == release
        end

        it 'should fail when the release section is omitted' do
          lambda {
            plan = Planner.new({})
            plan.parse_releases
          }.should raise_error(ValidationMissingField)
        end

        it 'support multiple releases per deployment' do
          plan = Planner.new({ 'releases' => releases_spec })
          plan.parse_releases
          plan.releases.size.should == 2
          plan.releases[0].spec.should == releases_spec[0]
          plan.releases[1].spec.should == releases_spec[1]
          plan.releases.each do |release|
            release.should be_kind_of(ReleaseVersion)
          end

          plan.release('foo').should == plan.releases[0]
          plan.release('bar').should == plan.releases[1]
        end

        it "supports either 'releases' or 'release' manifest section, not both" do
          expect {
            plan = Planner.new({
                                 'releases' => releases_spec,
                                 'release' => release_spec
                               })
            plan.parse_releases
          }.to raise_error(/use one of the two/)
        end

        it 'should detect duplicate release names' do
          expect {
            plan = Planner.new({
                                 'releases' => [release_spec,
                                                release_spec]
                               })
            plan.parse_releases
          }.to raise_error(/duplicate release name/i)
        end

      end

      describe :parse_networks do
        it 'should create manual network by default' do
          network_spec = instance_double('Bosh::Director::DeploymentPlan::Network')
          network_spec.stub(:name).and_return('Bar')
          network_spec.stub(:canonical_name).and_return('bar')
          network_spec

          received_plan = nil
          ManualNetwork.should_receive(:new).
            and_return do |deployment_plan, spec|
            received_plan = deployment_plan
            spec.should == { 'foo' => 'bar' }
            network_spec
          end
          plan = Planner.new({ 'networks' => [{ 'foo' => 'bar' }] })
          plan.parse_networks
          received_plan.should == plan
        end

        it 'should enforce canonical name uniqueness' do
          ManualNetwork.stub(:new).
            and_return do |deployment_plan, spec|
            network_spec = instance_double('Bosh::Director::DeploymentPlan::Network')
            network_spec.stub(:name).and_return(spec['name'])
            network_spec.stub(:canonical_name).and_return(spec['cname'])
            network_spec
          end

          lambda {
            plan = Planner.new({ 'networks' => [
              { 'name' => 'bar', 'cname' => 'bar' },
              { 'name' => 'Bar', 'cname' => 'bar' }
            ] })
            plan.parse_networks
          }.should raise_error(DeploymentCanonicalNetworkNameTaken,
                               "Invalid network name `Bar', canonical name already taken")
        end

        it 'should require at least one network' do
          lambda {
            plan = Planner.new({ 'networks' => [] })
            plan.parse_networks
          }.should raise_error(DeploymentNoNetworks, 'No networks specified')

          lambda {
            plan = Planner.new({})
            plan.parse_networks
          }.should raise_error(ValidationMissingField)
        end
      end

      describe :parse_compilation do
        it 'should delegate to CompilationConfig' do
          received_plan = nil
          CompilationConfig.
            should_receive(:new) do |deployment_plan, spec|
            received_plan = deployment_plan
            spec.should == { 'foo' => 'bar' }
          end
          plan = Planner.new({ 'compilation' => { 'foo' => 'bar' } })
          plan.parse_compilation
          received_plan.should == plan
        end

        it 'should fail when the compilation section is omitted' do
          lambda {
            plan = Planner.new({})
            plan.parse_compilation
          }.should raise_error(ValidationMissingField)
        end
      end

      describe :parse_update do
        it 'should delegate to UpdateConfig' do
          UpdateConfig.should_receive(:new) do |spec|
            spec.should == { 'foo' => 'bar' }
          end
          plan = Planner.new({ 'update' => { 'foo' => 'bar' } })
          plan.parse_update
        end

        it 'should fail when the update section is omitted' do
          lambda {
            plan = Planner.new({})
            plan.parse_update
          }.should raise_error(ValidationMissingField)
        end

      end

      describe :parse_resource_pools do
        it 'should delegate to ResourcePool' do
          resource_pool_spec = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
          resource_pool_spec.stub(:name).and_return('foo')

          received_plan = nil
          ResourcePool.should_receive(:new).
            and_return do |deployment_plan, spec|
            received_plan = deployment_plan
            spec.should == { 'foo' => 'bar' }
            resource_pool_spec
          end

          plan = Planner.new({ 'resource_pools' => [{ 'foo' => 'bar' }] })
          plan.parse_resource_pools
          plan.resource_pools.should == [resource_pool_spec]
          plan.resource_pool('foo').should == resource_pool_spec
          received_plan.should == plan
        end

        it 'should enforce name uniqueness' do
          ResourcePool.stub(:new).
            and_return do |_, spec|
            resource_pool_spec = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
            resource_pool_spec.stub(:name).and_return(spec['name'])
            resource_pool_spec
          end
          lambda {
            plan = Planner.new(
              { 'resource_pools' => [{ 'name' => 'bar' }, { 'name' => 'bar' }] }
            )
            plan.parse_resource_pools
          }.should raise_error(DeploymentDuplicateResourcePoolName,
                               "Duplicate resource pool name `bar'")
        end
      end

      describe :parse_jobs do
        it 'should delegate to Job' do
          job_spec = instance_double('Bosh::Director::DeploymentPlan::Job')
          job_spec.stub(:name).and_return('Foo')
          job_spec.stub(:canonical_name).and_return('foo')
          job_spec

          received_plan = nil
          Job.should_receive(:parse).
            and_return do |deployment_plan, spec|
            received_plan = deployment_plan
            spec.should == { 'foo' => 'bar' }
            job_spec
          end
          plan = Planner.new({ 'jobs' => [{ 'foo' => 'bar' }] })
          plan.parse_jobs
          received_plan.should == plan
        end

        it 'should enforce canonical name uniqueness' do
          Job.stub(:parse).
            and_return do |_, spec|
            job_spec = instance_double('Bosh::Director::DeploymentPlan::Job')
            job_spec.stub(:name).and_return(spec['name'])
            job_spec.stub(:canonical_name).and_return(spec['cname'])
            job_spec
          end
          lambda {
            plan = Planner.new({ 'jobs' => [
              { 'name' => 'Bar', 'cname' => 'bar' },
              { 'name' => 'bar', 'cname' => 'bar' }
            ] })
            plan.parse_jobs
          }.should raise_error(DeploymentCanonicalJobNameTaken,
                               "Invalid job name `bar', " +
                                 'canonical name already taken')
        end

        it 'should raise exception if renamed job is being referenced in deployment' do
          lambda {
            plan = Planner.new(
              { 'jobs' => [{ 'name' => 'bar' }] },
              { 'job_rename' => { 'old_name' => 'bar', 'new_name' => 'foo' } }
            )
            plan.parse_jobs
          }.should raise_error(DeploymentRenamedJobNameStillUsed,
                               "Renamed job `bar' is still referenced " +
                                 'in deployment manifest')
        end

        it 'should allow you to not have any jobs' do
          plan = Planner.new({ 'jobs' => [] })
          plan.parse_jobs

          plan.jobs.should be_empty

          plan = Planner.new({})
          plan.parse_jobs
          plan.jobs.should be_empty
        end
      end

      describe :bind_model do

        def make_plan(manifest)
          Planner.new(manifest)
        end

        def find_deployment(name)
          Models::Deployment.find(name: name)
        end

        def make_deployment(name)
          Models::Deployment.make(name: name)
        end

        describe 'binding deployment model' do
          it 'creates new deployment in DB using name from the manifest' do
            plan = make_plan({ 'name' => 'mycloud' })
            plan.parse_name

            find_deployment('mycloud').should be_nil
            plan.bind_model

            plan.model.should == find_deployment('mycloud')
            Models::Deployment.count.should == 1
          end

          it 'uses an existing deployment model if found in DB' do
            plan = make_plan({ 'name' => 'mycloud' })
            plan.parse_name

            deployment = make_deployment('mycloud')
            plan.bind_model
            plan.model.should == deployment
            Models::Deployment.count.should == 1
          end

          it 'enforces canonical name uniqueness' do
            make_deployment('my-cloud')
            plan = make_plan('name' => 'my_cloud')
            plan.parse_name

            expect {
              plan.bind_model
            }.to raise_error(DeploymentCanonicalNameTaken)

            plan.model.should be_nil
            Models::Deployment.count.should == 1
          end

          it 'only works when name and canonical name are known' do
            plan = make_plan('name' => 'my_cloud')
            expect {
              plan.bind_model
            }.to raise_error(DirectorError)

            plan.parse_name
            lambda { plan.bind_model }.should_not raise_error
          end
        end

        describe 'getting VM models list' do
          it 'raises an error when deployment model is unbound' do
            plan = make_plan('name' => 'my_cloud')
            plan.parse_name

            expect {
              plan.vms
            }.to raise_error(DirectorError)

            make_deployment('mycloud')
            plan.bind_model
            lambda { plan.vms }.should_not raise_error
          end

          it 'returns a list of VMs in deployment' do
            plan = make_plan('name' => 'my_cloud')
            plan.parse_name

            deployment = make_deployment('my_cloud')
            vm1 = Models::Vm.make(deployment: deployment)
            vm2 = Models::Vm.make(deployment: deployment)

            plan.bind_model
            plan.vms.should =~ [vm1, vm2]
          end
        end
      end
    end

  end
end
