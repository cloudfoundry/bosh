require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Steps::PackageCompileStep do
    let(:job) { double('job').as_null_object }

    let(:release_version_model) do
      Models::ReleaseVersion.make
    end

    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end

    before do
      allow(ThreadPool).to receive_messages(new: thread_pool) # Using threads for real, even accidentally makes debugging a nightmare

      allow(Config).to receive_messages(redis: double('fake-redis'))

      @cloud = double(:cpi)
      allow(Config).to receive(:cloud).and_return(@cloud)

      @blobstore = double(:blobstore)
      allow(Config).to receive(:blobstore).and_return(@blobstore)

      @director_job = instance_double('Bosh::Director::Jobs::BaseJob')
      allow(Config).to receive(:current_job).and_return(@director_job)
      allow(@director_job).to receive(:task_cancelled?).and_return(false)

      @deployment = Models::Deployment.make(name: 'mycloud')
      @config = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig')
      @plan = instance_double('Bosh::Director::DeploymentPlan::Planner', compilation: @config, model: @deployment, name: 'mycloud')
      @network = instance_double('Bosh::Director::DeploymentPlan::Network', name: 'default')

      @n_workers = 3
      allow(@config).to receive_messages(deployment: @plan,
                   network: @network,
                   env: {},
                   cloud_properties: {},
                   workers: @n_workers,
                   reuse_compilation_vms: false)

      allow(Config).to receive(:use_compiled_package_cache?).and_return(false)
      @all_packages = []
    end

    def make_package(name, deps = [], version = '0.1-dev')
      package = Models::Package.make(name: name, version: version)
      package.dependency_set = deps
      package.save
      @all_packages << package
      package
    end

    def make_compiled(release_version_model, package, stemcell, sha1 = 'deadbeef', blobstore_id = 'deadcafe')
      transitive_dependencies = release_version_model.transitive_dependencies(package)
      package_dependency_key = Models::CompiledPackage.create_dependency_key(transitive_dependencies)
      package_cache_key = Models::CompiledPackage.create_cache_key(package, transitive_dependencies, stemcell)

      CompileTask.new(package, stemcell, job, package_dependency_key, package_cache_key)

      Models::CompiledPackage.make(package: package,
                                   dependency_key: package_dependency_key,
                                   stemcell: stemcell,
                                   build: 1,
                                   sha1: sha1,
                                   blobstore_id: blobstore_id)
    end

    def prepare_samples
      @release = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'cf-release', model: release_version_model)
      @stemcell_a = instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: Models::Stemcell.make)
      @stemcell_b = instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: Models::Stemcell.make)

      @p_common = make_package('common')
      @p_syslog = make_package('p_syslog')
      @p_dea = make_package('dea', %w(ruby common))
      @p_ruby = make_package('ruby', %w(common))
      @p_warden = make_package('warden', %w(common))
      @p_nginx = make_package('nginx', %w(common))
      @p_router = make_package('p_router', %w(ruby common))
      @p_deps_ruby = make_package('needs_ruby', %w(ruby))

      rp_large = double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'large', stemcell: @stemcell_a)

      rp_small = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'small', stemcell: @stemcell_b)

      @t_dea = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_dea, @p_nginx, @p_syslog], name: 'dea')

      @t_warden = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_warden], name: 'warden')

      @t_nginx = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_nginx], name: 'nginx')

      @t_router = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_router], name: 'router')

      @t_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::Template', release: @release, package_models: [@p_deps_ruby], name: 'needs_ruby')

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

      @j_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::Job',
                                     name: 'needs_ruby',
                                     release: @release,
                                     templates: [@t_deps_ruby],
                                     resource_pool: rp_small)
      
      @package_set_a = [@p_dea, @p_nginx, @p_syslog, @p_warden, @p_common, @p_ruby]

      @package_set_b = [@p_nginx, @p_common, @p_router, @p_warden, @p_ruby]

      @package_set_c = [@p_deps_ruby]

      (@package_set_a + @package_set_b + @package_set_c).each do |package|
        release_version_model.packages << package
      end
    end

    context 'when all needed packages are compiled' do
      it "doesn't perform any compilation" do
        prepare_samples

        allow(@plan).to receive(:jobs).and_return([@j_dea, @j_router])

        @package_set_a.each do |package|
          cp1 = make_compiled(release_version_model, package, @stemcell_a.model)
          expect(@j_dea).to receive(:use_compiled_package).with(cp1)
        end

        @package_set_b.each do |package|
          cp2 = make_compiled(release_version_model, package, @stemcell_b.model)
          expect(@j_router).to receive(:use_compiled_package).with(cp2)
        end

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, nil, logger, Config.event_log, nil)

        compiler.perform
        # For @stemcell_a we need to compile:
        # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
        # For @stemcell_b:
        # [p_nginx, p_common, p_router, p_ruby, p_warden] = 5
        expect(compiler.compile_tasks_count).to eq(6 + 5)
        # But they are already compiled!
        expect(compiler.compilations_performed).to eq(0)

        expect(log_string).to include("Job templates `cf-release/dea', `cf-release/warden' need to run on stemcell `#{@stemcell_a.model.desc}'")
        expect(log_string).to include("Job templates `cf-release/nginx', `cf-release/router', `cf-release/warden' need to run on stemcell `#{@stemcell_b.model.desc}'")
      end
    end

    context 'when none of the packages are compiled' do
      it 'compiles all packages' do
        prepare_samples

        allow(@plan).to receive(:jobs).and_return([@j_dea, @j_router])
        compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, @cloud, logger, Config.event_log, @director_job)

        expect(@network).to receive(:reserve).at_least(@n_workers).times do |reservation|
          expect(reservation).to be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        expect(@network).to receive(:network_settings).
            exactly(11).times.and_return('network settings')

        net = {'default' => 'network settings'}
        vm_cids = (0..10).map { |i| "vm-cid-#{i}" }
        agents = (0..10).map { instance_double('Bosh::Director::AgentClient') }

        expect(@cloud).to receive(:create_vm).exactly(6).times.
            with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
            and_return(*vm_cids[0..5])

        expect(@cloud).to receive(:create_vm).exactly(5).times.
            with(instance_of(String), @stemcell_b.model.cid, {}, net, nil, {}).
            and_return(*vm_cids[6..10])

        expect(AgentClient).to receive(:with_defaults).exactly(11).times.and_return(*agents)

        vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
        allow(Bosh::Director::VmMetadataUpdater).to receive_messages(build: vm_metadata_updater)
        expect(vm_metadata_updater).to receive(:update).with(anything, { compiling: 'common'})
        expect(vm_metadata_updater).to receive(:update).with(anything, hash_including(:compiling)).exactly(10).times

        agents.each do |agent|
          initial_state = {
              'deployment' => 'mycloud',
              'resource_pool' => {},
              'networks' => net
          }

          expect(agent).to receive(:wait_until_ready)
          expect(agent).to receive(:update_settings)
          expect(agent).to receive(:apply).with(initial_state)
          expect(agent).to receive(:compile_package) do |*args|
            name = args[2]
            dot = args[3].rindex('.')
            version, build = args[3][0..dot-1], args[3][dot+1..-1]

            package = Models::Package.find(name: name, version: version)
            expect(args[0]).to eq(package.blobstore_id)
            expect(args[1]).to eq(package.sha1)

            expect(args[4]).to be_a(Hash)

            {
                'result' => {
                    'sha1' => "compiled #{package.id}",
                    'blobstore_id' => "blob #{package.id}"
                }
            }
          end
        end

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, @stemcell_a.model.id).and_yield
        end

        @package_set_b.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, @stemcell_b.model.id).and_yield
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times
        expect(@j_router).to receive(:use_compiled_package).exactly(5).times

        vm_cids.each do |vm_cid|
          expect(@cloud).to receive(:delete_vm).with(vm_cid)
        end

        expect(@network).to receive(:release).at_least(@n_workers).times
        expect(@director_job).to receive(:task_checkpoint).once

        compiler.perform
        expect(compiler.compilations_performed).to eq(11)

        @package_set_a.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end

        @package_set_b.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end
      end
    end

    context 'compiling packages with transitive dependencies' do
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:compiler) { DeploymentPlan::Steps::PackageCompileStep.new(@plan, @cloud, logger, Config.event_log, @director_job) }
      let(:net) { {'default' => 'network settings'} }
      let(:vm_cid) { "vm-cid-0" }

      before do
        prepare_samples

        allow(@network).to receive(:reserve) do |reservation|
          expect(reservation).to be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater', update: nil)
        allow(Bosh::Director::VmMetadataUpdater).to receive_messages(build: vm_metadata_updater)
        expect(vm_metadata_updater).to receive(:update).with(anything, hash_including(:compiling))

        initial_state = {
            'deployment' => 'mycloud',
            'resource_pool' => {},
            'networks' => net
        }

        allow(AgentClient).to receive(:with_defaults).and_return(agent)
        allow(agent).to receive(:wait_until_ready)
        allow(agent).to receive(:update_settings)
        allow(agent).to receive(:apply).with(initial_state)
        allow(agent).to receive(:compile_package) do |*args|
          name = args[2]
          {
              'result' => {
                  'sha1' => "compiled.#{name}.sha1",
                  'blobstore_id' => "blob.#{name}.id"
              }
          }
        end

        allow(@network).to receive(:network_settings).and_return('network settings')
        allow(@network).to receive(:release)
        allow(@director_job).to receive(:task_checkpoint)
        allow(compiler).to receive(:with_compile_lock).and_yield
        allow(@cloud).to receive(:delete_vm)
      end

      it 'sends information about immediate dependencies of the package being compiled' do

        allow(@plan).to receive(:jobs).and_return([@j_deps_ruby])

        allow(@cloud).to receive(:create_vm).
                              with(instance_of(String), @stemcell_b.model.cid, {}, net, nil, {}).
                              and_return(vm_cid)

        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
                             "common", # package name
                             "0.1-dev.1", # package version
                             {}).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
                             "ruby", # package name
                             "0.1-dev.1", # package version
                             {"common"=>{"name"=>"common", "version"=>"0.1-dev.1", "sha1"=>"compiled.common.sha1", "blobstore_id"=>"blob.common.id"}}).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
                             "needs_ruby", # package name
                             "0.1-dev.1", # package version
                             {"ruby"=>{"name"=>"ruby", "version"=>"0.1-dev.1", "sha1"=>"compiled.ruby.sha1", "blobstore_id"=>"blob.ruby.id"}}).ordered # immediate dependencies

        allow(@j_deps_ruby).to receive(:use_compiled_package)

        compiler.perform
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
        allow(event_log).to receive(:track).with(anything).and_yield

        config = class_double('Bosh::Director::Config').as_stubbed_const
        allow(config).to receive_messages(
          current_job: director_job,
          cloud: double('cpi'),
          event_log: event_log,
          logger: logger,
          use_compiled_package_cache?: false,
        )

        network = double('network', name: 'network_name')
        compilation_config = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig', network: network, cloud_properties: {}, env: {}, workers: 1,
                                    reuse_compilation_vms: true)
        release_version_model = instance_double('Bosh::Director::Models::ReleaseVersion', dependencies: Set.new, transitive_dependencies: Set.new)
        release_version = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'release_name', model: release_version_model)
        stemcell_model = double('stemcell_model', desc: 'stemcell description', id: 'stemcell_id', sha1: 'beef')
        stemcell = double('stemcell', model: stemcell_model)
        resource_pool = double('resource_pool', stemcell: stemcell)
        job = instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version, name: 'job_name', resource_pool: resource_pool)
        package_model = instance_double('Bosh::Director::Models::Package', name: 'foobarbaz', desc: 'package description', id: 'package_id', dependency_set: [],
                               fingerprint: 'deadbeef')
        template = instance_double('Bosh::Director::DeploymentPlan::Template', release: release_version, package_models: [ package_model ], name: 'fake_template')
        allow(job).to receive_messages(templates: [template])
        planner = instance_double('Bosh::Director::DeploymentPlan::Planner', compilation: compilation_config, name: 'mycloud')

        allow(planner).to receive(:jobs).and_return([job])

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(planner, @cloud, logger, event_log, director_job)

        expect {
          compiler.perform
        }.not_to raise_error
      end
    end

    describe 'with reuse_compilation_vms option set' do
      let(:net) { {'default' => 'network settings'} }
      let(:initial_state) {
        {
          'deployment' => 'mycloud',
          'resource_pool' => {},
          'networks' => net
        }
      }

      it 'reuses compilation VMs' do
        prepare_samples
        allow(@plan).to receive(:jobs).and_return([@j_dea])

        allow(@config).to receive_messages(reuse_compilation_vms: true)

        expect(@network).to receive(:reserve).at_most(@n_workers).times do |reservation|
          expect(reservation).to be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        expect(@network).to receive(:network_settings).
          at_most(3).times.and_return('network settings')

        vm_cids = (0..2).map { |i| "vm-cid-#{i}" }
        agents = (0..2).map { instance_double('Bosh::Director::AgentClient') }

        expect(@cloud).to receive(:create_vm).at_most(3).times.
          with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
          and_return(*vm_cids)

        expect(AgentClient).to receive(:with_defaults).at_most(3).times.and_return(*agents)

        agents.each do |agent|
          expect(agent).to receive(:wait_until_ready).at_most(6).times
          expect(agent).to receive(:update_settings).at_most(6).times
          expect(agent).to receive(:apply).with(initial_state).at_most(6).times
          expect(agent).to receive(:compile_package).at_most(6).times do |*args|
            name = args[2]
            dot = args[3].rindex('.')
            version, build = args[3][0..dot-1], args[3][dot+1..-1]

            package = Models::Package.find(name: name, version: version)
            expect(args[0]).to eq(package.blobstore_id)
            expect(args[1]).to eq(package.sha1)

            expect(args[4]).to be_a(Hash)

            {
              'result' => {
                'sha1' => "compiled #{package.id}",
                'blobstore_id' => "blob #{package.id}"
              }
            }
          end
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times

        vm_cids.each do |vm_cid|
          expect(@cloud).to receive(:delete_vm).at_most(1).times.with(vm_cid)
        end

        expect(@network).to receive(:release).at_most(@n_workers).times
        expect(@director_job).to receive(:task_checkpoint).once

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, @cloud, logger, Config.event_log, @director_job)

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, @stemcell_a.model.id).and_yield
        end

        compiler.perform
        expect(compiler.compilations_performed).to eq(6)

        @package_set_a.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end
      end

      it 'cleans up compilation vms if there is a failing compilation' do
        prepare_samples
        allow(@plan).to receive(:jobs).and_return([@j_dea])

        allow(@config).to receive_messages(reuse_compilation_vms: true)
        allow(@config).to receive_messages(workers: 1)

        expect(@network).to receive(:reserve) do |reservation|
          expect(reservation).to be_an_instance_of(NetworkReservation)
          reservation.reserved = true
        end

        expect(@network).to receive(:network_settings).and_return('network settings')

        vm_cid = 'vm-cid-1'
        agent = instance_double('Bosh::Director::AgentClient')

        expect(@cloud).to receive(:create_vm).
          with(instance_of(String), @stemcell_a.model.cid, {}, net, nil, {}).
          and_return(vm_cid)

        expect(AgentClient).to receive(:with_defaults).and_return(agent)

        expect(agent).to receive(:wait_until_ready)
        expect(agent).to receive(:update_settings)
        expect(agent).to receive(:apply).with(initial_state)
        expect(agent).to receive(:compile_package).and_raise(RuntimeError)

        expect(@cloud).to receive(:delete_vm).with(vm_cid)

        expect(@network).to receive(:release)

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, @cloud, logger, Config.event_log, @director_job)
        allow(compiler).to receive(:with_compile_lock).and_yield

        expect {
          compiler.perform
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

        allow(@plan).to receive_messages(jobs: [job])
      end

      before do # create vm
        allow(@network).to receive(:reserve) { |reservation| reservation.reserved = true }
        allow(@network).to receive(:network_settings)
        allow(@cloud).to receive(:create_vm).and_return('vm-cid-1')
      end

      def self.it_tears_down_vm_exactly_once
        it 'tears down VMs exactly once when RpcTimeout error occurs' do
          # agent raises error
          agent = instance_double('Bosh::Director::AgentClient', apply: nil)
          expect(agent).to receive(:wait_until_ready).and_raise(RpcTimeout)
          expect(AgentClient).to receive(:with_defaults).and_return(agent)

          # vm is destroyed
          expect(@cloud).to receive(:delete_vm)
          expect(@network).to receive(:release)

          compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, @cloud, logger, Config.event_log, @director_job)
          allow(compiler).to receive(:with_compile_lock).and_yield
          expect { compiler.perform }.to raise_error(RpcTimeout)
        end
      end

      context 'reuse_compilation_vms is true' do
        before { allow(@config).to receive_messages(reuse_compilation_vms: true) }
        it_tears_down_vm_exactly_once
      end

      context 'reuse_compilation_vms is false' do
        before { allow(@config).to receive_messages(reuse_compilation_vms: false) }
        it_tears_down_vm_exactly_once
      end
    end

    it 'should make sure a parallel deployment did not compile a package already' do
      package = Models::Package.make
      stemcell = Models::Stemcell.make

      task = CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key')

      compiler = DeploymentPlan::Steps::PackageCompileStep.new(@plan, nil, logger, Config.event_log, nil)
      fake_compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
      allow(task).to receive(:find_compiled_package).and_return(fake_compiled_package)

      allow(compiler).to receive(:with_compile_lock).with(package.id, stemcell.id).and_yield
      compiler.compile_package(task)

      expect(task.compiled_package).to eq(fake_compiled_package)
    end

    describe 'the global blobstore' do
      let(:package) { Models::Package.make }
      let(:stemcell) { Models::Stemcell.make }
      let(:task) { CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key') }
      let(:compiler) { DeploymentPlan::Steps::PackageCompileStep.new(@plan, nil, logger, Config.event_log, nil) }
      let(:cache_key) { 'cache key' }

      before do
        allow(task).to receive(:cache_key).and_return(cache_key)

        allow(Config).to receive(:use_compiled_package_cache?).and_return(true)
      end

      it 'should check if compiled package is in global blobstore' do
        allow(compiler).to receive(:with_compile_lock).with(package.id, stemcell.id).and_yield

        expect(BlobUtil).to receive(:exists_in_global_cache?).with(package, cache_key).and_return(true)
        allow(task).to receive(:find_compiled_package)
        expect(BlobUtil).not_to receive(:save_to_global_cache)
        allow(compiler).to receive(:prepare_vm)
        compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end

      it 'should save compiled package to global cache if not exists' do
        expect(compiler).to receive(:with_compile_lock).with(package.id, stemcell.id).and_yield

        allow(task).to receive(:find_compiled_package)
        compiled_package = instance_double(
          'Bosh::Director::Models::CompiledPackage',
          name: 'fake-package-name', package: package,
          stemcell: stemcell, blobstore_id: 'some blobstore id')
        expect(BlobUtil).to receive(:exists_in_global_cache?).with(package, cache_key).and_return(false)
        expect(BlobUtil).to receive(:save_to_global_cache).with(compiled_package, cache_key)
        allow(compiler).to receive(:prepare_vm)
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end

      it 'only checks the global cache if Config.use_compiled_package_cache? is set' do
        allow(Config).to receive(:use_compiled_package_cache?).and_return(false)

        allow(compiler).to receive(:with_compile_lock).with(package.id, stemcell.id).and_yield

        expect(BlobUtil).not_to receive(:exists_in_global_cache?)
        expect(BlobUtil).not_to receive(:save_to_global_cache)
        allow(compiler).to receive(:prepare_vm)
        compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end
    end

    describe '#prepare_vm' do
      let(:network) { double('network', name: 'name', network_settings: nil) }
      let(:compilation) do
        config = double('compilation_config')
        allow(config).to receive_messages(network: network)
        allow(config).to receive_messages(cloud_properties: double('cloud_properties'))
        allow(config).to receive_messages(env: double('env'))
        allow(config).to receive_messages(workers: 2)
        config
      end
      let(:deployment_plan) { double('Bosh::Director::DeploymentPlan', compilation: compilation, model: 'model') }
      let(:stemcell) { Models::Stemcell.make }
      let(:vm) { Models::Vm.make }
      let(:vm_data) { instance_double('Bosh::Director::VmData', vm: vm) }
      let(:reuser) { instance_double('Bosh::Director::VmReuser') }

      context 'with reuse_compilation_vms' do
        before do
          allow(compilation).to receive_messages(reuse_compilation_vms: true)
          allow(VmCreator).to receive_messages(create: vm)
          allow(VmReuser).to receive_messages(new: reuser)
        end

        it 'should clean up the compilation vm if it failed' do
          compiler = described_class.new(deployment_plan, @cloud, logger, Config.event_log, @director_job)

          allow(compiler).to receive_messages(reserve_network: double('network_reservation'))
          client = instance_double('Bosh::Director::AgentClient')
          allow(client).to receive(:wait_until_ready).and_raise(RpcTimeout)
          allow(AgentClient).to receive_messages(with_defaults: client)

          allow(reuser).to receive_messages(get_vm: nil)
          allow(reuser).to receive_messages(get_num_vms: 0)
          allow(reuser).to receive_messages(add_vm: vm_data)

          expect(reuser).to receive(:remove_vm).with(vm_data)
          expect(vm_data).to receive(:release)

          expect(compiler).to receive(:tear_down_vm).with(vm_data)

          expect {
            compiler.prepare_vm(stemcell) do
              # nothing
            end
          }.to raise_error RpcTimeout
        end
      end

      describe 'trusted certificate handling' do
        let(:compiler) { described_class.new(deployment_plan, @cloud, logger, Config.event_log, @director_job) }
        let(:client) { instance_double('Bosh::Director::AgentClient') }
        before do
          Bosh::Director::Config.trusted_certs=DIRECTOR_TEST_CERTS
          allow(VmCreator).to receive_messages(create: vm)
          allow(AgentClient).to receive_messages(with_defaults: client)
          allow(@cloud).to receive(:delete_vm)
          allow(vm_data).to receive(:release)

          allow(compilation).to receive_messages(reuse_compilation_vms: true)

          allow(compiler).to receive_messages(reserve_network: double('network_reservation'))
          allow(compiler).to receive(:tear_down_vm)
          allow(compiler).to receive(:configure_vm)

          allow(client).to receive(:update_settings)
          allow(client).to receive(:wait_until_ready)
        end

        it 'should update the database with the new VM''s trusted certs' do
          compiler.prepare_vm(stemcell) {
            # prepare_vm needs a block. so here it is.
          }
          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1, agent_id: vm.agent_id).count).to eq(1)
        end

        it 'should not update the DB with the new certificates when the new vm fails to start' do
          expect(client).to receive(:wait_until_ready).and_raise(RpcTimeout)

          begin
            compiler.prepare_vm(stemcell)
          rescue RpcTimeout
            #
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end

        it 'should not update the DB with the new certificates when the update_settings method fails' do
          expect(client).to receive(:update_settings).and_raise(RpcTimeout)

          begin
            compiler.prepare_vm(stemcell)
          rescue RpcTimeout
            # expected
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end
      end
    end
  end
end
