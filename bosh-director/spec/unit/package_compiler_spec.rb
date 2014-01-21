require 'spec_helper'

module Bosh::Director
  describe PackageCompiler do
    let(:job) { double('job').as_null_object }

    let(:release_version_model) do
      Models::ReleaseVersion.make
    end

    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      thread_pool.stub(:wrap).and_yield(thread_pool)
      thread_pool.stub(:process).and_yield
      thread_pool.stub(:working?).and_return(false)
      thread_pool
    end

    before do
      ThreadPool.stub(new: thread_pool) # Using threads for real, even accidentally makes debugging a nightmare

      Config.stub(redis: double('fake-redis'))

      @cloud = double(:cpi)
      Config.stub(:cloud).and_return(@cloud)

      @blobstore = double(:blobstore)
      Config.stub(:blobstore).and_return(@blobstore)

      @director_job = instance_double('Bosh::Director::Jobs::BaseJob')
      Config.stub(:current_job).and_return(@director_job)
      @director_job.stub(:task_cancelled?).and_return(false)

      @deployment = Models::Deployment.make(name: 'mycloud')
      @config = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig')
      @plan = instance_double('Bosh::Director::DeploymentPlan::Planner', compilation: @config, model: @deployment, name: 'mycloud')
      @network = instance_double('Bosh::Director::DeploymentPlan::Network', name: 'default')

      @n_workers = 3
      @config.stub(deployment: @plan,
                   network: @network,
                   env: {},
                   cloud_properties: {},
                   workers: @n_workers,
                   reuse_compilation_vms: false)

      Config.stub(:use_compiled_package_cache?).and_return(false)
      @all_packages = []
    end

    def make_package(name, deps = [], version = '0.1-dev')
      package = Models::Package.make(name: name, version: version)
      package.dependency_set = deps
      package.save
      @all_packages << package
      package
    end

    def make_compiled(package, stemcell, sha1 = 'deadbeef',
      blobstore_id = 'deadcafe')
      dep_key = release_version_model.package_dependency_key(package.name)
      cache_key = release_version_model.package_cache_key(package.name, stemcell)
      CompileTask.new(package, stemcell, job, dep_key, cache_key)

      Models::CompiledPackage.make(package: package,
                                   dependency_key: dep_key,
                                   stemcell: stemcell,
                                   build: 1,
                                   sha1: sha1,
                                   blobstore_id: blobstore_id)
    end

    def prepare_samples
      @release = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
                                 name: 'cf-release',
                                 model: release_version_model)
      @stemcell_a = instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: Models::Stemcell.make)
      @stemcell_b = instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: Models::Stemcell.make)

      @p_common = make_package('common')
      @p_syslog = make_package('p_syslog')
      @p_dea = make_package('dea', %w(ruby common))
      @p_ruby = make_package('ruby', %w(common))
      @p_warden = make_package('warden', %w(common))
      @p_nginx = make_package('nginx', %w(common))
      @p_router = make_package('p_router', %w(ruby common))

      rp_large = double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'large', stemcell: @stemcell_a)

      rp_small = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'small', stemcell: @stemcell_b)

      @t_dea = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_dea, @p_nginx, @p_syslog], name: 'dea')

      @t_warden = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_warden], name: 'warden')

      @t_nginx = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_nginx], name: 'nginx')

      @t_router = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_router], name: 'router')

      @j_dea = instance_double('Bosh::Director::DeploymentPlan::Job',
                               name: 'dea',
                               release: @release,
                               templates: [@t_dea, @t_warden],
                               resource_pool: rp_large)
      @j_router = instance_double('Bosh::Director::DeploymentPlan::Job',
                                  name: 'router',
                                  release: @release,
                                  templates: [@t_nginx, @t_router, @t_warden],
                                  resource_pool: rp_small)

      @package_set_a = [@p_dea, @p_nginx, @p_syslog, @p_warden, @p_common, @p_ruby]

      @package_set_b = [@p_nginx, @p_common, @p_router, @p_warden, @p_ruby]

      (@package_set_a + @package_set_b).each do |package|
        release_version_model.packages << package
      end
    end

    context 'when all needed packages are compiled' do
      it "doesn't perform any compilation" do
        prepare_samples

        @plan.stub(:jobs).and_return([@j_dea, @j_router])

        @package_set_a.each do |package|
          cp1 = make_compiled(package, @stemcell_a.model)
          @j_dea.should_receive(:use_compiled_package).with(cp1)
        end

        @package_set_b.each do |package|
          cp2 = make_compiled(package, @stemcell_b.model)
          @j_router.should_receive(:use_compiled_package).with(cp2)
        end

        logger = instance_double('Logger', info: nil, debug: nil)
        Config.stub(logger: logger)

        compiler = PackageCompiler.new(@plan)

        expect(logger).to receive(:info).with("Job templates `cf-release/dea', `cf-release/warden' need to run on stemcell `#{@stemcell_a.model.desc}'")
        expect(logger).to receive(:info).with("Job templates `cf-release/nginx', `cf-release/router', `cf-release/warden' need to run on stemcell `#{@stemcell_b.model.desc}'")

        compiler.compile
        # For @stemcell_a we need to compile:
        # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
        # For @stemcell_b:
        # [p_nginx, p_common, p_router, p_ruby, p_warden] = 5
        compiler.compile_tasks_count.should == 6 + 5
        # But they are already compiled!
        compiler.compilations_performed.should == 0
      end
    end

    context 'when none of the packages are compiled' do
      it 'compiles all packages' do
        prepare_samples

        @plan.stub(:jobs).and_return([@j_dea, @j_router])
        compiler = PackageCompiler.new(@plan)

        @network.should_receive(:reserve).at_least(@n_workers).times do |reservation|
          reservation.should be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        @network.should_receive(:network_settings).
            exactly(11).times.and_return('network settings')

        net = {'default' => 'network settings'}
        vm_cids = (0..10).map { |i| "vm-cid-#{i}" }
        agents = (0..10).map { instance_double('Bosh::Director::AgentClient') }

        @cloud.should_receive(:create_vm).exactly(6).times.
            with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
            and_return(*vm_cids[0..5])

        @cloud.should_receive(:create_vm).exactly(5).times.
            with(instance_of(String), @stemcell_b.model.cid, {}, net, nil, {}).
            and_return(*vm_cids[6..10])

        AgentClient.should_receive(:with_defaults).exactly(11).times.and_return(*agents)

        vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
        Bosh::Director::VmMetadataUpdater.stub(build: vm_metadata_updater)
        vm_metadata_updater.should_receive(:update).with(anything, { compiling: 'common'})
        vm_metadata_updater.should_receive(:update).with(anything, hash_including(:compiling)).exactly(10).times

        agents.each do |agent|
          initial_state = {
              'deployment' => 'mycloud',
              'resource_pool' => 'package_compiler',
              'networks' => net
          }

          agent.should_receive(:wait_until_ready)
          agent.should_receive(:apply).with(initial_state)
          agent.should_receive(:compile_package) do |*args|
            name = args[2]
            dot = args[3].rindex('.')
            version, build = args[3][0..dot-1], args[3][dot+1..-1]

            package = Models::Package.find(name: name, version: version)
            args[0].should == package.blobstore_id
            args[1].should == package.sha1

            args[4].should be_a(Hash)

            {
                'result' => {
                    'sha1' => "compiled #{package.id}",
                    'blobstore_id' => "blob #{package.id}"
                }
            }
          end
        end

        @package_set_a.each do |package|
          compiler.should_receive(:with_compile_lock).with(package.id, @stemcell_a.model.id).and_yield
        end

        @package_set_b.each do |package|
          compiler.should_receive(:with_compile_lock).with(package.id, @stemcell_b.model.id).and_yield
        end

        @j_dea.should_receive(:use_compiled_package).exactly(6).times
        @j_router.should_receive(:use_compiled_package).exactly(5).times

        vm_cids.each do |vm_cid|
          @cloud.should_receive(:delete_vm).with(vm_cid)
        end

        @network.should_receive(:release).at_least(@n_workers).times
        @director_job.should_receive(:task_checkpoint).once

        compiler.compile
        compiler.compilations_performed.should == 11

        @package_set_a.each do |package|
          package.compiled_packages.size.should >= 1
        end

        @package_set_b.each do |package|
          package.compiled_packages.size.should >= 1
        end
      end
    end

    context 'when the deploy is cancelled and there is a pending compilation' do
      # this can happen when the cancellation comes in when there is a package to be compiled,
      # and the compilation is not even in-flight. e.g.
      # - you have 3 compilation workers, but you've got 5 packages to compile; or
      # - package "bar" depends on "foo", deploy is cancelled when compiling "foo" ("bar" is blocked)

      it 'cancels the compilation' do
        director_job = instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, task_cancelled?: true)
        event_log = instance_double('Bosh::Director::EventLog::Log', begin_stage: nil)
        event_log.stub(:track).with(anything).and_yield

        config = class_double('Bosh::Director::Config').as_stubbed_const
        config.stub(
          current_job: director_job,
          cloud: double('cpi'),
          event_log: event_log,
          logger: double('logger', info: nil, debug: nil),
          use_compiled_package_cache?: false,
        )

        network = double('network', name: 'network_name')
        compilation_config = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig', network: network, cloud_properties: {}, env: {}, workers: 1,
                                    reuse_compilation_vms: true)
        release_version_model = instance_double('Bosh::Director::Models::ReleaseVersion',
                                                dependencies: [], package_dependency_key: 'fake-dependency-key', package_cache_key: 'fake-cache-key')
        release_version = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'release_name', model: release_version_model)
        stemcell_model = double('stemcell_model', desc: 'stemcell description', id: 'stemcell_id', sha1: 'beef')
        stemcell = double('stemcell', model: stemcell_model)
        resource_pool = double('resource_pool', stemcell: stemcell)
        job = instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version, name: 'job_name', resource_pool: resource_pool)
        package_model = instance_double('Bosh::Director::Models::Package', name: 'foobarbaz', desc: 'package description', id: 'package_id', dependency_set: [],
                               fingerprint: 'deadbeef')
        template = instance_double('Bosh::Director::DeploymentPlan::Template', release: release_version, package_models: [ package_model ], name: 'fake_template')
        job.stub(templates: [template])
        planner = instance_double('Bosh::Director::DeploymentPlan::Planner', compilation: compilation_config, name: 'mycloud')

        planner.stub(:jobs).and_return([job])

        compiler = PackageCompiler.new(planner)

        expect {
          compiler.compile
        }.not_to raise_error
      end
    end

    describe 'with reuse_compilation_vms option set' do
      let(:net) { {'default' => 'network settings'} }
      let(:initial_state) {
        {
          'deployment' => 'mycloud',
          'resource_pool' => 'package_compiler',
          'networks' => net
        }
      }

      it 'reuses compilation VMs' do
        prepare_samples
        @plan.stub(:jobs).and_return([@j_dea])

        @config.stub(reuse_compilation_vms: true)

        @network.should_receive(:reserve).at_most(@n_workers).times do |reservation|
          reservation.should be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        @network.should_receive(:network_settings).
          at_most(3).times.and_return('network settings')

        vm_cids = (0..2).map { |i| "vm-cid-#{i}" }
        agents = (0..2).map { instance_double('Bosh::Director::AgentClient') }

        @cloud.should_receive(:create_vm).at_most(3).times.
          with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
          and_return(*vm_cids)

        AgentClient.should_receive(:with_defaults).at_most(3).times.and_return(*agents)

        agents.each do |agent|
          agent.should_receive(:wait_until_ready).at_most(6).times
          agent.should_receive(:apply).with(initial_state).at_most(6).times
          agent.should_receive(:compile_package).at_most(6).times do |*args|
            name = args[2]
            dot = args[3].rindex('.')
            version, build = args[3][0..dot-1], args[3][dot+1..-1]

            package = Models::Package.find(name: name, version: version)
            args[0].should == package.blobstore_id
            args[1].should == package.sha1

            args[4].should be_a(Hash)

            {
              'result' => {
                'sha1' => "compiled #{package.id}",
                'blobstore_id' => "blob #{package.id}"
              }
            }
          end
        end

        @j_dea.should_receive(:use_compiled_package).exactly(6).times

        vm_cids.each do |vm_cid|
          @cloud.should_receive(:delete_vm).at_most(1).times.with(vm_cid)
        end

        @network.should_receive(:release).at_most(@n_workers).times
        @director_job.should_receive(:task_checkpoint).once

        compiler = PackageCompiler.new(@plan)

        @package_set_a.each do |package|
          compiler.should_receive(:with_compile_lock).with(package.id, @stemcell_a.model.id).and_yield
        end

        compiler.compile
        compiler.compilations_performed.should == 6

        @package_set_a.each do |package|
          package.compiled_packages.size.should >= 1
        end
      end

      it 'cleans up compilation vms if there is a failing compilation' do
        prepare_samples
        @plan.stub(:jobs).and_return([@j_dea])

        @config.stub(reuse_compilation_vms: true)
        @config.stub(workers: 1)

        @network.should_receive(:reserve) do |reservation|
          reservation.should be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        @network.should_receive(:network_settings).and_return('network settings')

        vm_cid = 'vm-cid-1'
        agent = instance_double('Bosh::Director::AgentClient')

        @cloud.should_receive(:create_vm).
          with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
          and_return(vm_cid)

        AgentClient.should_receive(:with_defaults).and_return(agent)

        agent.should_receive(:wait_until_ready)
        agent.should_receive(:apply).with(initial_state)
        agent.should_receive(:compile_package).and_raise(RuntimeError)

        @cloud.should_receive(:delete_vm).with(vm_cid)

        @network.should_receive(:release)

        compiler = PackageCompiler.new(@plan)
        compiler.stub(:with_compile_lock).and_yield

        expect {
          compiler.compile
        }.to raise_error(RuntimeError)
      end
    end

    describe 'tearing down compilation vms' do
      before do # prepare compilation
        prepare_samples

        release  = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',  model: release_version_model, name: 'release')
        stemcell = instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: Models::Stemcell.make)
        resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', stemcell: stemcell)

        package  = make_package('common')
        template = instance_double('Bosh::Director::DeploymentPlan::Template', release: release, package_models: [package], name: 'fake_template')
        job      = instance_double(
          'Bosh::Director::DeploymentPlan::Job',
          name: 'job-with-one-package',
          release: release,
          templates: [template],
          resource_pool: resource_pool,
        )

        @plan.stub(jobs: [job])
      end

      before do # create vm
        @network.stub(:reserve) { |reservation| reservation.reserved = true }
        @network.stub(:network_settings)
        @cloud.stub(:create_vm).and_return('vm-cid-1')
      end

      def self.it_tears_down_vm_exactly_once
        it 'tears down VMs exactly once when RpcTimeout error occurs' do
          # agent raises error
          agent = instance_double('Bosh::Director::AgentClient', apply: nil)
          agent.should_receive(:wait_until_ready).and_raise(RpcTimeout)
          AgentClient.should_receive(:with_defaults).and_return(agent)

          # vm is destroyed
          @cloud.should_receive(:delete_vm)
          @network.should_receive(:release)

          compiler = PackageCompiler.new(@plan)
          compiler.stub(:with_compile_lock).and_yield
          expect { compiler.compile }.to raise_error(RpcTimeout)
        end
      end

      context 'reuse_compilation_vms is true' do
        before { @config.stub(reuse_compilation_vms: true) }
        it_tears_down_vm_exactly_once
      end

      context 'reuse_compilation_vms is false' do
        before { @config.stub(reuse_compilation_vms: false) }
        it_tears_down_vm_exactly_once
      end
    end

    it 'should make sure a parallel deployment did not compile a package already' do
      package = Models::Package.make
      stemcell = Models::Stemcell.make

      task = CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key')

      compiler = PackageCompiler.new(@plan)
      fake_compiled_package = instance_double('Bosh::Director::Models::CompiledPackage')
      task.stub(:find_compiled_package).and_return(fake_compiled_package)

      compiler.stub(:with_compile_lock).with(package.id, stemcell.id).and_yield
      compiler.compile_package(task)

      task.compiled_package.should == fake_compiled_package
    end

    describe 'the global blobstore' do
      let(:package) { Models::Package.make }
      let(:stemcell) { Models::Stemcell.make }
      let(:task) { CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key') }
      let(:compiler) { PackageCompiler.new(@plan) }
      let(:cache_key) { 'cache key' }

      before do
        task.stub(:cache_key).and_return(cache_key)

        Config.stub(:use_compiled_package_cache?).and_return(true)
      end

      it 'should check if compiled package is in global blobstore' do
        compiler.stub(:with_compile_lock).with(package.id, stemcell.id).and_yield

        BlobUtil.should_receive(:exists_in_global_cache?).with(package, cache_key).and_return(true)
        task.stub(:find_compiled_package)
        BlobUtil.should_not_receive(:save_to_global_cache)
        compiler.stub(:prepare_vm)
        Models::CompiledPackage.stub(:create)

        compiler.compile_package(task)
      end

      it 'should save compiled package to global cache if not exists' do
        compiler.should_receive(:with_compile_lock).with(package.id, stemcell.id).and_yield

        task.stub(:find_compiled_package)
        compiled_package = double('compiled package', package: package, stemcell: stemcell, blobstore_id: 'some blobstore id')
        BlobUtil.should_receive(:exists_in_global_cache?).with(package, cache_key).and_return(false)
        BlobUtil.should_receive(:save_to_global_cache).with(compiled_package, cache_key)
        compiler.stub(:prepare_vm)
        Models::CompiledPackage.stub(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end

      it 'only checks the global cache if Config.use_compiled_package_cache? is set' do
        Config.stub(:use_compiled_package_cache?).and_return(false)

        compiler.stub(:with_compile_lock).with(package.id, stemcell.id).and_yield

        BlobUtil.should_not_receive(:exists_in_global_cache?)
        BlobUtil.should_not_receive(:save_to_global_cache)
        compiler.stub(:prepare_vm)
        Models::CompiledPackage.stub(:create)

        compiler.compile_package(task)
      end
    end

    describe '#prepare_vm' do
      let(:network) { double('network', name: 'name', network_settings: nil) }
      let(:compilation) do
        config = double('compilation_config')
        config.stub(network: network)
        config.stub(cloud_properties: double('cloud_properties'))
        config.stub(env: double('env'))
        config.stub(workers: 2)
        config
      end
      let(:deployment_plan) { double('Bosh::Director::DeploymentPlan', compilation: compilation, model: 'model') }
      let(:stemcell) { Models::Stemcell.make }
      let(:vm) { Models::Vm.make }
      let(:vm_data) { instance_double('Bosh::Director::VmData', vm: vm) }
      let(:reuser) { instance_double('Bosh::Director::VmReuser') }

      context 'with reuse_compilation_vms' do
        before do
          compilation.stub(reuse_compilation_vms: true)
          VmCreator.stub(create: vm)
          VmReuser.stub(new: reuser)
        end

        it 'should clean up the compilation vm if it failed' do
          compiler = described_class.new(deployment_plan)

          compiler.stub(reserve_network: double('network_reservation'))
          client = instance_double('Bosh::Director::AgentClient')
          client.stub(:wait_until_ready).and_raise(RpcTimeout)
          AgentClient.stub(with_defaults: client)

          reuser.stub(get_vm: nil)
          reuser.stub(get_num_vms: 0)
          reuser.stub(add_vm: vm_data)

          reuser.should_receive(:remove_vm).with(vm_data)
          vm_data.should_receive(:release)

          compiler.should_receive(:tear_down_vm).with(vm_data)

          expect {
            compiler.prepare_vm(stemcell) do
              # nothing
            end
          }.to raise_error RpcTimeout
        end
      end
    end
  end
end
