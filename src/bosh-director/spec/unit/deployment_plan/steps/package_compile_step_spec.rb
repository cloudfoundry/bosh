require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Steps::PackageCompileStep do
    include Support::StemcellHelpers

    let(:job) { double('job').as_null_object }
    let(:cloud) { Config.cloud }
    let(:vm_deleter) { VmDeleter.new(Config.logger, false, false) }
    let(:agent_broadcaster) { AgentBroadcaster.new }
    let(:vm_creator) { VmCreator.new(Config.logger, vm_deleter, disk_manager, job_renderer, agent_broadcaster) }
    let(:job_renderer) { instance_double(JobRenderer, render_job_instances: nil) }
    let(:disk_manager) {DiskManager.new(logger)}
    let(:release_version_model) { Models::ReleaseVersion.make }
    let(:reuse_compilation_vms) { false }
    let(:number_of_workers) { 3 }
    let(:compilation_config) do
      compilation_spec = {
        'workers' => number_of_workers,
        'network' => 'default',
        'env' => {},
        'cloud_properties' => {},
        'reuse_compilation_vms' => reuse_compilation_vms,
        'az' => '',
      }
      DeploymentPlan::CompilationConfig.new(compilation_spec, {}, [])
    end
    let(:deployment) { Models::Deployment.make(name: 'mycloud') }
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner',
        compilation: compilation_config,
        model: deployment,
        name: 'mycloud',
        ip_provider: ip_provider,
        recreate: false
      )
    end
    let(:instance_reuser) { InstanceReuser.new }
    let(:instance_deleter) { instance_double(Bosh::Director::InstanceDeleter)}
    let(:ip_provider) { instance_double(DeploymentPlan::IpProvider, reserve: nil, release: nil)}
    let(:compilation_instance_pool) do
      DeploymentPlan::CompilationInstancePool.new(instance_reuser, vm_creator, plan, logger, instance_deleter, 4)
    end
    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end
    let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'default', network_settings: {'network_name' =>{'property' => 'settings'}}) }
    let(:net) { {'default' => {'network_name' =>{'property' => 'settings'}}} }
    let(:event_manager) {Api::EventManager.new(true)}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager)}
    let(:expected_groups) {
      [
        'fake-director-name',
        'mycloud',
        'compilation-deadbeef',
        'fake-director-name-mycloud',
        'mycloud-compilation-deadbeef',
        'fake-director-name-mycloud-compilation-deadbeef'
      ]
    }

    before do
      Bosh::Director::Models::VariableSet.make(deployment: deployment)

      allow(ThreadPool).to receive_messages(new: thread_pool) # Using threads for real, even accidentally, makes debugging a nightmare

      allow(instance_deleter).to receive(:delete_instance_plan)

      @blobstore = double(:blobstore)
      allow(Config).to receive(:blobstore).and_return(@blobstore)

      @director_job = instance_double('Bosh::Director::Jobs::BaseJob')
      allow(Config).to receive(:current_job).and_return(@director_job)
      allow(@director_job).to receive(:task_cancelled?).and_return(false)

      allow(plan).to receive(:network).with('default').and_return(network)

      allow(Config).to receive(:use_compiled_package_cache?).and_return(false)

      allow(Config).to receive(:current_job).and_return(update_job)
      allow(Config).to receive(:name).and_return('fake-director-name')
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
      transitive_dependencies = PackageDependenciesManager.new(release_version_model).transitive_dependencies(package)
      package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, release_version_model)
      package_cache_key = Models::CompiledPackage.create_cache_key(package, transitive_dependencies, stemcell.sha1)

      CompileTask.new(package, stemcell, job, package_dependency_key, package_cache_key)

      Models::CompiledPackage.make(package: package,
        dependency_key: package_dependency_key,
        stemcell_os: stemcell.operating_system,
        stemcell_version: stemcell.version,
        build: 1,
        sha1: sha1,
        blobstore_id: blobstore_id)
    end

    def prepare_samples
      @release = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'cf-release', model: release_version_model)
      @stemcell_a = make_stemcell(operating_system: 'chrome-os', version: '3146.1')
      @stemcell_b = make_stemcell(operating_system: 'chrome-os', version: '3146.2')

      @p_common = make_package('common')
      @p_syslog = make_package('p_syslog')
      @p_dea = make_package('dea', %w(ruby common))
      @p_ruby = make_package('ruby', %w(common))
      @p_warden = make_package('warden', %w(common))
      @p_nginx = make_package('nginx', %w(common))
      @p_router = make_package('p_router', %w(ruby common))
      @p_deps_ruby = make_package('needs_ruby', %w(ruby))

      vm_type_large = instance_double('Bosh::Director::DeploymentPlan::VmType', name: 'large')
      vm_type_small = instance_double('Bosh::Director::DeploymentPlan::VmType', name: 'small')

      @t_dea = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_dea, @p_nginx, @p_syslog], name: 'dea')

      @t_warden = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_warden], name: 'warden')

      @t_nginx = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_nginx], name: 'nginx')

      @t_router = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_router], name: 'router')

      @t_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_deps_ruby], name: 'needs_ruby')

      @j_dea = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'dea',
        release: @release,
        jobs: [@t_dea, @t_warden],
        vm_type: vm_type_large,
        stemcell: @stemcell_a
      )

      @j_router = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'router',
        release: @release,
        jobs: [@t_nginx, @t_router, @t_warden],
        vm_type: vm_type_small,
        stemcell: @stemcell_b
      )

      @j_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'needs_ruby',
        release: @release,
        jobs: [@t_deps_ruby],
        vm_type: vm_type_small,
        stemcell: @stemcell_b
      )

      @package_set_a = [@p_dea, @p_nginx, @p_syslog, @p_warden, @p_common, @p_ruby]

      @package_set_b = [@p_nginx, @p_common, @p_router, @p_warden, @p_ruby]

      @package_set_c = [@p_deps_ruby]

      (@package_set_a + @package_set_b + @package_set_c).each do |package|
        release_version_model.packages << package
      end
    end

    def compile_package_stub(args)
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

    context 'when all needed packages are compiled' do
      it "doesn't perform any compilation" do
        prepare_samples

        @package_set_a.each do |package|
          cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
          expect(@j_dea).to receive(:use_compiled_package).with(cp1)
        end

        @package_set_b.each do |package|
          cp2 = make_compiled(release_version_model, package, @stemcell_b.models.first)
          expect(@j_router).to receive(:use_compiled_package).with(cp2)
        end

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(
          [@j_dea, @j_router],
          compilation_config,
          compilation_instance_pool,
          logger,
          nil
        )

        compiler.perform
        # For @stemcell_a we need to compile:
        # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
        # For @stemcell_b:
        # [p_nginx, p_common, p_router, p_ruby, p_warden] = 5
        expect(compiler.compile_tasks_count).to eq(6 + 5)
        # But they are already compiled!
        expect(compiler.compilations_performed).to eq(0)

        expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_a.desc}'")
        expect(log_string).to include("Job templates 'cf-release/nginx', 'cf-release/router', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
      end
    end

    context 'when none of the packages are compiled' do
      it 'compiles all packages' do
        prepare_samples

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(
          [@j_dea, @j_router],
          compilation_config,
          compilation_instance_pool,
          logger,
          @director_job
        )

        expect(vm_creator).to receive(:create_for_instance_plan).exactly(11).times

        metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)

        allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, {compiling: 'common'})
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, hash_including(:compiling)).exactly(10).times

        agent_client = instance_double('Bosh::Director::AgentClient')
        allow(BD::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
        expect(agent_client).to receive(:compile_package).exactly(11).times do |*args|
          compile_package_stub(args)
        end

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}").and_yield
        end

        @package_set_b.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}").and_yield
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times
        expect(@j_router).to receive(:use_compiled_package).exactly(5).times

        expect(instance_deleter).to receive(:delete_instance_plan).exactly(11).times

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

    context 'when there are compiled packages with the same major version number but different patch number' do

      before do
        prepare_samples

        @j_dea = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
          name: 'dea',
          release: @release,
          jobs: [@t_dea, @t_warden],
          vm_type: @vm_type_large,
          stemcell: @stemcell_b
        )
      end

      context 'and we are using a source release' do
        it 'compiles all packages' do
          compiler = DeploymentPlan::Steps::PackageCompileStep.new(
            [@j_dea],
            compilation_config,
            compilation_instance_pool,
            logger,
            @director_job
          )

          @package_set_a.each do |package|
            cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
            expect(@j_dea).not_to receive(:use_compiled_package).with(cp1)
            expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}").and_yield
          end

          expect(vm_creator).to receive(:create_for_instance_plan).exactly(6).times

          agent_client = instance_double('Bosh::Director::AgentClient')
          allow(BD::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
          expect(agent_client).to receive(:compile_package).exactly(6).times do |*args|
            compile_package_stub(args)
          end

          expect(@director_job).to receive(:task_checkpoint).once

          compiler.perform
          # For @stemcell_b we need to compile:
          # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
          expect(compiler.compile_tasks_count).to eq(6)
          # and they should be recompiled
          expect(compiler.compilations_performed).to eq(6)

          expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
        end
      end

      context 'and we are using a compiled release' do
        it 'does not compile any packages' do
          compiler = DeploymentPlan::Steps::PackageCompileStep.new(
            [@j_dea],
            compilation_config,
            compilation_instance_pool,
            logger,
            @director_job
          )

          @package_set_a.each do |package|
            package.blobstore_id = nil
            package.sha1 = nil
            cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
            expect(@j_dea).to receive(:use_compiled_package).with(cp1)
            expect(compiler).not_to receive(:with_compile_lock).with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}").and_yield
          end

          compiler.perform
          # For @stemcell_b we need to compile:
          # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
          expect(compiler.compile_tasks_count).to eq(6)
          # and they should be recompiled
          expect(compiler.compilations_performed).to eq(0)

          expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
        end
      end
    end

    context 'compiling packages with transitive dependencies' do
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:compiler) { DeploymentPlan::Steps::PackageCompileStep.new([@j_deps_ruby], compilation_config, compilation_instance_pool, logger, @director_job) }
      let(:vm_cid) { 'vm-cid-0' }

      before do
        prepare_samples

        metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)
        allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, hash_including(:compiling))

        initial_state = {
            'deployment' => 'mycloud',
            'vm_type' => {},
            'stemcell' => {},
            'networks' => net
        }

        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)
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

        allow(@director_job).to receive(:task_checkpoint)
        allow(compiler).to receive(:with_compile_lock).and_yield
        allow(vm_creator).to receive(:create_for_instance_plan)
      end

      it 'sends information about immediate dependencies of the package being compiled' do
        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
            'common', # package name
            '0.1-dev.1', # package version
                             {}).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
            'ruby', # package name
            '0.1-dev.1', # package version
                             {'common' =>{'name' => 'common', 'version' => '0.1-dev.1', 'sha1' => 'compiled.common.sha1', 'blobstore_id' => 'blob.common.id'}}).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
                             anything(), # source package blobstore id
                             anything(), # source package sha1
            'needs_ruby', # package name
            '0.1-dev.1', # package version
                             {'ruby' =>{'name' => 'ruby', 'version' => '0.1-dev.1', 'sha1' => 'compiled.ruby.sha1', 'blobstore_id' => 'blob.ruby.id'}}).ordered # immediate dependencies

        allow(@j_deps_ruby).to receive(:use_compiled_package)

        compiler.perform
      end
    end

    context 'when the deploy is cancelled and there is a pending compilation' do
      let(:reuse_compilation_vms) { true }
      let(:number_of_workers) { 1 }
      # this can happen when the cancellation comes in when there is a package to be compiled,
      # and the compilation is not even in-flight. e.g.
      # - you have 3 compilation workers, but you've got 5 packages to compile; or
      # - package "bar" depends on "foo", deploy is cancelled when compiling "foo" ("bar" is blocked)

      it 'cancels the compilation' do
        director_job = instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, task_cancelled?: true)
        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        allow(event_log_stage).to receive(:advance_and_track).with(anything).and_yield

        network = double('network', name: 'network_name')
        release_version_model = Models::ReleaseVersion.make
        release_version = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'release_name', model: release_version_model)
        stemcell = make_stemcell
        instance_group = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', release: release_version, name: 'job_name', stemcell: stemcell)
        package_model = Models::Package.make(name: 'foobarbaz', dependency_set: [], fingerprint: 'deadbeef', blobstore_id: 'fake_id')
        job = instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version, package_models: [package_model], name: 'fake_template')
        allow(instance_group).to receive_messages(jobs: [job])

        compiler = DeploymentPlan::Steps::PackageCompileStep.new([instance_group], compilation_config, compilation_instance_pool, logger, director_job)

        expect {
          compiler.perform
        }.not_to raise_error
      end
    end

    describe 'with reuse_compilation_vms option set' do
      let(:reuse_compilation_vms) { true }
      let(:initial_state) {
        {
          'deployment' => 'mycloud',
          'job' => {
            'name' => 'compilation-deadbeef'
          },
          'index' => 0,
          'id' => 'deadbeef',
          'networks' => net
        }
      }
      before { allow(SecureRandom).to receive(:uuid).and_return('deadbeef') }

      let(:vm_creator) { Bosh::Director::VmCreator.new(logger, vm_deleter, disk_manager, job_renderer, agent_broadcaster) }
      let(:disk_manager) { DiskManager.new(logger) }

      it 'reuses compilation VMs' do
        prepare_samples

        expect(vm_creator).to receive(:create_for_instance_plan).exactly(1).times

        agent_client = instance_double('BD::AgentClient')
        allow(BD::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)

        expect(agent_client).to receive(:compile_package).exactly(6).times do |*args|
          name = args[2]
          dot = args[3].rindex('.')
          version, _ = args[3][0..dot-1], args[3][dot+1..-1]

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

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times

        expect(instance_deleter).to receive(:delete_instance_plan)

        expect(@director_job).to receive(:task_checkpoint).once

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(
          [@j_dea],
          compilation_config,
          compilation_instance_pool,
          logger,
          @director_job
        )

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}").and_yield
        end

        compiler.perform
        expect(compiler.compilations_performed).to eq(6)

        @package_set_a.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end
      end

      it 'cleans up compilation vms if there is a failing compilation' do
        prepare_samples

        vm_cid = 'vm-cid-1'
        agent = instance_double('Bosh::Director::AgentClient')

        expect(cloud).to receive(:create_vm).
          with(instance_of(String), @stemcell_a.models.first.cid, {}, net, [], {'bosh' => {'group' => 'fake-director-name-mycloud-compilation-deadbeef', 'groups' => expected_groups}}).
          and_return(vm_cid)

        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)

        expect(agent).to receive(:wait_until_ready)
        expect(agent).to receive(:update_settings)
        expect(agent).to receive(:apply).with(initial_state)
        expect(agent).to receive(:get_state).and_return({'agent-state' => 'yes'})
        expect(agent).to receive(:compile_package).and_raise(RuntimeError)

        compiler = DeploymentPlan::Steps::PackageCompileStep.new(
          [@j_dea],
          compilation_config,
          compilation_instance_pool,
          logger,
          @director_job
        )
        allow(compiler).to receive(:with_compile_lock).and_yield

        expect {
          compiler.perform
        }.to raise_error(RuntimeError)
      end
    end

    describe 'tearing down compilation vms' do
      before do # prepare compilation
        prepare_samples
      end

      let(:job) do
        release = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', model: release_version_model, name: 'release')
        stemcell = make_stemcell

        package = make_package('common')
        job = instance_double('Bosh::Director::DeploymentPlan::Job', release: release, package_models: [package], name: 'fake_template')

        instance_double(
          'Bosh::Director::DeploymentPlan::InstanceGroup',
          name: 'job-with-one-package',
          release: release,
          jobs: [job],
          vm_type: {},
          stemcell: stemcell,
        )
      end

      before do # create vm
        allow(cloud).to receive(:create_vm).and_return('vm-cid-1')
      end

      def self.it_tears_down_vm_exactly_once(exception)
        it "tears down VMs exactly once when #{exception} error occurs" do
          # agent raises error
          agent = instance_double('Bosh::Director::AgentClient')
          expect(agent).to receive(:wait_until_ready).and_raise(exception)
          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)

          expect(cloud).to receive(:delete_vm).once

          compiler = DeploymentPlan::Steps::PackageCompileStep.new([job], compilation_config, compilation_instance_pool, logger, @director_job)
          allow(compiler).to receive(:with_compile_lock).and_yield
          expect { compiler.perform }.to raise_error(exception)
        end
      end

      context 'reuse_compilation_vms is true' do
        it_tears_down_vm_exactly_once(RpcTimeout)
        it_tears_down_vm_exactly_once(TaskCancelled)
      end

      context 'reuse_compilation_vms is false' do
        let(:reuse_compilation_vms) { false }
        it_tears_down_vm_exactly_once(RpcTimeout)
        it_tears_down_vm_exactly_once(TaskCancelled)
      end
    end

    it 'should make sure a parallel deployment did not compile a package already' do
      package = Models::Package.make
      stemcell = make_stemcell

      task = CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key')

      compiler = DeploymentPlan::Steps::PackageCompileStep.new([], compilation_config, compilation_instance_pool, logger, nil)
      fake_compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
      allow(task).to receive(:find_compiled_package).and_return(fake_compiled_package)

      allow(compiler).to receive(:with_compile_lock).with(package.id, "#{stemcell.os}/#{stemcell.version}").and_yield
      compiler.compile_package(task)

      expect(task.compiled_package).to eq(fake_compiled_package)
    end

    describe 'the global blobstore' do
      let(:package) { Models::Package.make }
      let(:stemcell) { make_stemcell }
      let(:task) { CompileTask.new(package, stemcell, job, 'fake-dependency-key', 'fake-cache-key') }
      let(:compiler) { DeploymentPlan::Steps::PackageCompileStep.new([], compilation_config, compilation_instance_pool, logger, nil) }
      let(:cache_key) { 'cache key' }

      before do
        allow(task).to receive(:cache_key).and_return(cache_key)

        allow(Config).to receive(:use_compiled_package_cache?).and_return(true)
      end

      it 'should check if compiled package is in global blobstore' do
        allow(compiler).to receive(:with_compile_lock).with(package.id, "#{stemcell.os}/#{stemcell.version}").and_yield

        expect(BlobUtil).to receive(:exists_in_global_cache?).with(package, cache_key).and_return(true)
        allow(task).to receive(:find_compiled_package)
        expect(BlobUtil).not_to receive(:save_to_global_cache)
        allow(compiler).to receive(:prepare_vm)
        compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end

      it 'should save compiled package to global cache if not exists' do
        expect(compiler).to receive(:with_compile_lock).with(package.id, "#{stemcell.os}/#{stemcell.version}").and_yield

        allow(task).to receive(:find_compiled_package)
        compiled_package = instance_double(
          'Bosh::Director::Models::CompiledPackage',
          name: 'fake-package-name', package: package,
          stemcell_os: stemcell.os, stemcell_version: stemcell.version, blobstore_id: 'some blobstore id')
        expect(BlobUtil).to receive(:exists_in_global_cache?).with(package, cache_key).and_return(false)
        expect(BlobUtil).to receive(:save_to_global_cache).with(compiled_package, cache_key)
        allow(compiler).to receive(:prepare_vm)
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end

      it 'only checks the global cache if Config.use_compiled_package_cache? is set' do
        allow(Config).to receive(:use_compiled_package_cache?).and_return(false)

        allow(compiler).to receive(:with_compile_lock).with(package.id, "#{stemcell.os}/#{stemcell.version}").and_yield

        expect(BlobUtil).not_to receive(:exists_in_global_cache?)
        expect(BlobUtil).not_to receive(:save_to_global_cache)
        allow(compiler).to receive(:prepare_vm)
        compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
        allow(Models::CompiledPackage).to receive(:create).and_return(compiled_package)

        compiler.compile_package(task)
      end
    end

    describe '#prepare_vm' do
      let(:number_of_workers) { 2 }
      let(:plan) do
        deployment_model = Models::Deployment.make
        Bosh::Director::Models::VariableSet.make(deployment: deployment_model)

        instance_double('Bosh::Director::DeploymentPlan::Planner',
          compilation: compilation_config,
          model: deployment_model,
          name: 'fake-deployment',
          ip_provider: ip_provider
        )
      end
      let(:stemcell) { make_stemcell(cid: 'stemcell-cid') }
      let(:instance) { instance_double(DeploymentPlan::Instance) }

      context 'with reuse_compilation_vms' do
        let(:reuse_compilation_vms) { true }
        let(:network) { instance_double('Bosh::Director::DeploymentPlan::ManualNetwork', name: 'default', network_settings: nil) }
        let(:instance_reuser) { instance_double('Bosh::Director::InstanceReuser') }

        before do
          allow(plan).to receive(:network).with('default').and_return(network)
        end

        it 'should clean up the compilation vm if it failed' do
          compiler = described_class.new([], compilation_config, compilation_instance_pool, logger, @director_job)

          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(RpcTimeout)

          allow(instance_reuser).to receive_messages(get_instance: nil)
          allow(instance_reuser).to receive_messages(get_num_instances: 0)
          allow(instance_reuser).to receive(:add_in_use_instance)
          allow(instance_reuser).to receive(:total_instance_count).and_return(3)
          allow(ip_provider).to receive(:reserve).with(instance_of(Bosh::Director::DesiredNetworkReservation))

          expect(instance_reuser).to receive(:remove_instance).ordered
          expect(instance_deleter).to receive(:delete_instance_plan).ordered
          allow(ip_provider).to receive(:release)

          expect {
            compiler.prepare_vm(stemcell) do
              # nothing
            end
          }.to raise_error RpcTimeout
        end
      end

      describe 'trusted certificate handling' do
        let(:compiler) { described_class.new([], compilation_config, compilation_instance_pool, logger, @director_job) }
        let(:client) { instance_double('Bosh::Director::AgentClient') }

        before do
          Bosh::Director::Config.trusted_certs = DIRECTOR_TEST_CERTS

          allow(cloud).to receive(:create_vm).and_return('new-vm-cid')
          allow(vm_creator).to receive(:apply_state)
          allow(AgentClient).to receive_messages(with_vm_credentials_and_agent_id: client)
          allow(cloud).to receive(:delete_vm)
          allow(client).to receive(:update_settings)
          allow(client).to receive(:wait_until_ready)
          allow(client).to receive(:apply)
          allow(client).to receive(:get_state)
        end

        def self.it_should_not_update_db(method, exception)
          it 'should not update the DB with the new certificates' do
            expect(client).to receive(method).and_raise(exception)

            begin
              compiler.prepare_vm(stemcell, &Proc.new {})
            rescue exception
              #
            end

            expect(Models::Instance.find(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1)).to be_nil
          end
        end

        it 'should update the database with the new VM' 's trusted certs' do
          expect {
            compiler.prepare_vm(stemcell, &Proc.new {})
          }.to change {
              Models::Instance.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count}.from(0).to(1)
        end

        context 'when the new vm fails to start' do
          it_should_not_update_db(:wait_until_ready, RpcTimeout)
        end

        context 'when task was cencelled' do
          it_should_not_update_db(:wait_until_ready, TaskCancelled)
        end

        context 'when the update_settings method fails' do
          it_should_not_update_db(:update_settings, RpcTimeout)
        end
      end
    end
  end
end
