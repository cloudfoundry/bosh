require 'spec_helper'

describe Bosh::Director::Jobs::UpdateDeployment do
  describe 'Resque job class expectations' do
    let(:job_type) { :update_deployment }
    it_behaves_like 'a Resque job'
  end

  describe 'instance methods' do
    before do
      @manifest = double('manifest')
      @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')

      @deployment_plan.stub(:name).and_return('test_deployment')
      @deployment_plan.should_receive(:parse).once

      pool1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
      pool2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
      updater1 =  instance_double('Bosh::Director::ResourcePoolUpdater')
      updater2 =  instance_double('Bosh::Director::ResourcePoolUpdater')

      Bosh::Director::ResourcePoolUpdater.stub(:new).with(pool1).and_return(updater1)
      Bosh::Director::ResourcePoolUpdater.stub(:new).with(pool2).and_return(updater2)

      @deployment_plan.stub(:resource_pools).and_return([pool1, pool2])

      @tmpdir = Dir.mktmpdir('base_dir')

      @manifest_file = Tempfile.new('manifest')
      File.open(@manifest_file.path, 'w') do |f|
        f.write('manifest')
      end

      Psych.stub(:load).with('manifest').and_return(@manifest)

      Bosh::Director::DeploymentPlan::Planner.stub(:new).with(@manifest, 'recreate' => false, 'job_states' => { },
                                                      'job_rename' => { }).and_return(@deployment_plan)
      Bosh::Director::Config.stub(:base_dir).and_return(@tmpdir)
    end

    after do
      FileUtils.rm_rf(@tmpdir)
    end

    describe 'prepare' do
      it 'should prepare the deployment plan' do
        Bosh::Director::Models::Deployment.make(name: 'test_deployment')
        assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
        package_compiler = instance_double('Bosh::Director::PackageCompiler')

        Bosh::Director::DeploymentPlan::Assembler.stub(:new).with(@deployment_plan).and_return(assembler)
        update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
        Bosh::Director::PackageCompiler.stub(:new).with(@deployment_plan).and_return(package_compiler)

        assembler.should_receive(:bind_deployment).ordered
        assembler.should_receive(:bind_releases).ordered
        assembler.should_receive(:bind_existing_deployment).ordered
        assembler.should_receive(:bind_resource_pools).ordered
        assembler.should_receive(:bind_stemcells).ordered
        assembler.should_receive(:bind_templates).ordered
        assembler.should_receive(:bind_properties).ordered
        assembler.should_receive(:bind_unallocated_vms).ordered
        assembler.should_receive(:bind_instance_networks).ordered
        package_compiler.should_receive(:compile)

        update_deployment_job.prepare

        check_event_log do |events|
          events.size.should == 18
          events.select { |e| e['stage'] == 'Preparing deployment' }.size.should == 18
        end
      end
    end

    describe '#update' do
      let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater') }

      it 'should update the deployment' do
        assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
        resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        resource_pool_updater =  instance_double('Bosh::Director::ResourcePoolUpdater')
        job =  instance_double('Bosh::Director::DeploymentPlan::Job')

        resource_pool_updater.stub(:extra_vm_count).and_return(2)
        resource_pool_updater.stub(:outdated_idle_vm_count).and_return(3)
        resource_pool_updater.stub(:bound_missing_vm_count).and_return(4)
        resource_pool_updater.stub(:missing_vm_count).and_return(5)

        Bosh::Director::ResourcePoolUpdater.stub(:new).with(resource_pool).and_return(resource_pool_updater)
        Bosh::Director::DeploymentPlan::BatchMultiJobUpdater.stub(:new).with(no_args).and_return(multi_job_updater)

        resource_pool.stub(:name).and_return('resource_pool_name')

        job.stub(:name).and_return('job_name')

        @deployment_plan.stub(:resource_pools).and_return([resource_pool])
        @deployment_plan.stub(:jobs).and_return([job])

        assembler.should_receive(:bind_dns).ordered

        resource_pool_updater.should_receive(:delete_extra_vms).ordered
        resource_pool_updater.should_receive(:delete_outdated_idle_vms).ordered
        resource_pool_updater.should_receive(:create_bound_missing_vms).ordered

        assembler.should_receive(:bind_instance_vms).ordered
        assembler.should_receive(:bind_configuration).ordered
        assembler.should_receive(:delete_unneeded_vms).ordered
        assembler.should_receive(:delete_unneeded_instances).ordered

        multi_job_updater.should_receive(:run).ordered

        resource_pool_updater.should_receive(:reserve_networks).ordered
        resource_pool_updater.should_receive(:create_missing_vms).ordered

        update_deployment_job = described_class.new(@manifest_file.path)
        update_deployment_job.instance_eval { @assembler = assembler }
        update_deployment_job.update

        check_event_log do |events|
          events.select { |e| e['task'] == 'Binding configuration' }.size.should == 2
        end
      end
    end

    describe 'update_stemcell_references' do
      it 'should delete references to no longer used stemcells' do
        deployment = Bosh::Director::Models::Deployment.make

        resource_pool_spec = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        stemcell_spec = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

        new_stemcell = Bosh::Director::Models::Stemcell.make
        old_stemcell = Bosh::Director::Models::Stemcell.make

        deployment.add_stemcell(old_stemcell)

        @deployment_plan.stub(:model).and_return(deployment)
        @deployment_plan.stub(:resource_pools).and_return([resource_pool_spec])

        Bosh::Director::ResourcePoolUpdater.stub(:new).with(resource_pool_spec).and_return(double('updater'))

        resource_pool_spec.stub(:stemcell).and_return(stemcell_spec)
        stemcell_spec.stub(:model).and_return(new_stemcell)

        update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
        update_deployment_job.update_stemcell_references

        old_stemcell.deployments.should be_empty
      end
    end

    describe 'perform' do
      it 'should do a basic update' do
        deployment = Bosh::Director::Models::Deployment.
            make(name: 'test_deployment')

        foo_release = Bosh::Director::Models::Release.make(name: 'foo_release')
        foo_release_version = Bosh::Director::Models::ReleaseVersion.
            make(release: foo_release, version: 17)

        bar_release = Bosh::Director::Models::Release.make(name: 'bar_release')
        bar_release_version = Bosh::Director::Models::ReleaseVersion.
            make(release: bar_release, version: 42)

        foo_release_spec = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
                                name: 'foo',
                                model: foo_release_version)

        bar_release_spec = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
                                name: 'bar',
                                model: bar_release_version)

        release_specs = [foo_release_spec, bar_release_spec]

        @deployment_plan.stub(:releases).and_return(release_specs)
        @deployment_plan.stub(:model).and_return(deployment)

        job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
        job.should_receive(:with_deployment_lock).with(@deployment_plan).
            and_yield.ordered
        job.should_receive(:prepare).ordered
        job.should_receive(:update).ordered
        job.should_receive(:with_release_locks).with(@deployment_plan).
            and_yield.ordered
        job.should_receive(:update_stemcell_references).ordered

        deployment.should_receive(:add_release_version).
            with(foo_release_version)

        deployment.should_receive(:add_release_version).
            with(bar_release_version)

        job.perform.should == '/deployments/test_deployment'

        deployment.refresh
        deployment.manifest.should == 'manifest'
      end
    end
  end
end
