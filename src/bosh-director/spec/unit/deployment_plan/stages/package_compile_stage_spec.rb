require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Stages::PackageCompileStage do
    include Support::StemcellHelpers

    let(:job) { double('job').as_null_object }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:vm_deleter) { VmDeleter.new(Config.logger, false, false) }
    let(:agent_broadcaster) { AgentBroadcaster.new }
    let(:dns_encoder) { instance_double(DnsEncoder) }
    let(:vm_creator) do
      VmCreator.new(Config.logger, template_blob_cache, dns_encoder, agent_broadcaster, plan.link_provider_intents)
    end
    let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
    let(:release_version_model) { Models::ReleaseVersion.make(version: 'new') }
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
      instance_double(
        'Bosh::Director::DeploymentPlan::Planner',
        compilation: compilation_config,
        model: deployment,
        name: 'mycloud',
        ip_provider: ip_provider,
        recreate: false,
        tags: {},
        link_provider_intents: [],
      )
    end
    let(:instance_reuser) { InstanceReuser.new }
    let(:instance_deleter) { instance_double(Bosh::Director::InstanceDeleter) }
    let(:ip_provider) { instance_double(DeploymentPlan::IpProvider, reserve: nil, release: nil) }
    let(:instance_provider) { DeploymentPlan::InstanceProvider.new(plan, vm_creator, logger) }
    let(:compilation_instance_pool) do
      DeploymentPlan::CompilationInstancePool.new(
        instance_reuser,
        instance_provider,
        logger,
        instance_deleter,
        compilation_config,
      )
    end
    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end
    let(:network) do
      instance_double(
        'Bosh::Director::DeploymentPlan::Network',
        name: 'default',
        network_settings: { network_name: { property: 'settings' } },
      )
    end
    let(:net) do
      { 'default' => { network_name: { property: 'settings' } } }
    end
    let(:event_manager) { Api::EventManager.new(true) }
    let(:job_task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, job_task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:update_job) do
      instance_double(
        Bosh::Director::Jobs::UpdateDeployment,
        username: 'user',
        task_id: job_task.id,
        event_manager: event_manager,
      )
    end
    let(:instance_groups_to_compile) { [] }
    let(:expected_groups) do
      %w[
        fake-director-name
        mycloud
        compilation-deadbeef
        fake-director-name-mycloud
        mycloud-compilation-deadbeef
        fake-director-name-mycloud-compilation-deadbeef
      ]
    end
    let(:initial_state) do
      {
        'deployment' => 'mycloud',
        'job' => {
          'name' => 'compilation-deadbeef',
        },
        'index' => 0,
        'id' => 'deadbeef',
        'networks' => net,
      }
    end

    let(:compiler) do
      DeploymentPlan::Stages::PackageCompileStage.new(
        deployment.name,
        instance_groups_to_compile,
        compilation_config,
        compilation_instance_pool,
        release_manager,
        package_validator,
        compiled_package_finder,
        logger,
      )
    end

    let(:package_validator) do
      DeploymentPlan::PackageValidator.new(logger)
    end

    let(:release_manager) do
      Bosh::Director::Api::ReleaseManager.new
    end

    let(:compiled_package_finder) { DeploymentPlan::CompiledPackageFinder.new(logger) }

    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }

    before do
      Bosh::Director::Models::VariableSet.make(deployment: deployment)

      allow(ThreadPool).to receive_messages(new: thread_pool) # Using threads for real, even accidentally, makes debugging a nightmare

      allow(instance_deleter).to receive(:delete_instance_plan)

      allow(plan).to receive(:network).with('default').and_return(network)

      allow(Config).to receive(:preferred_cpi_api_version).and_return(1)

      allow(Config).to receive(:current_job).and_return(update_job)
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Config).to receive(:enable_short_lived_nats_bootstrap_credentials_compilation_vms).and_return(false)
      director_config = SpecHelper.spec_get_director_config
      allow(Config).to receive(:nats_client_ca_private_key_path).and_return(director_config['nats']['client_ca_private_key_path'])
      allow(Config).to receive(:nats_client_ca_certificate_path).and_return(director_config['nats']['client_ca_certificate_path'])
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(cloud).to receive(:info)
      allow(cloud).to receive(:request_cpi_api_version=)
      allow(cloud).to receive(:request_cpi_api_version)
      allow(cloud).to receive(:set_vm_metadata)
      allow(Bosh::Clouds::ExternalCpi).to receive(:new).and_return(cloud)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
      allow(blobstore).to receive(:validate!)
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
      package_dependency_key = KeyGenerator.new.dependency_key_from_models(package, release_version_model)

      Models::CompiledPackage.make(package: package,
                                   dependency_key: package_dependency_key,
                                   stemcell_os: stemcell.operating_system,
                                   stemcell_version: stemcell.version,
                                   build: 1,
                                   sha1: sha1,
                                   blobstore_id: blobstore_id)
    end

    def prepare_samples
      @release = instance_double(
        'Bosh::Director::DeploymentPlan::ReleaseVersion',
        name: 'cf-release',
        model: release_version_model,
        version: 'new',
        exported_from: [],
      )
      @release_model = Bosh::Director::Models::Release.make(name: @release.name)
      @release_model.add_version(release_version_model)
      @stemcell_a = make_stemcell(operating_system: 'chrome-os', version: '3146.1', api_version: 3)
      @stemcell_b = make_stemcell(operating_system: 'chrome-os', version: '3146.2', api_version: 3)

      @p_common = make_package('common')
      @p_syslog = make_package('p_syslog')
      @p_dea = make_package('dea', %w[ruby common])
      @p_ruby = make_package('ruby', %w[common])
      @p_warden = make_package('warden', %w[common])
      @p_nginx = make_package('nginx', %w[common])
      @p_router = make_package('p_router', %w[ruby common])
      @p_deps_ruby = make_package('needs_ruby', %w[ruby])

      vm_type_large = instance_double('Bosh::Director::DeploymentPlan::VmType', name: 'large')
      vm_type_small = instance_double('Bosh::Director::DeploymentPlan::VmType', name: 'small')

      @t_dea = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_dea, @p_nginx, @p_syslog], name: 'dea')

      @t_warden = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_warden], name: 'warden')

      @t_nginx = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_nginx], name: 'nginx')

      @t_router = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_router], name: 'router')

      @t_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::Job', release: @release, package_models: [@p_deps_ruby], name: 'needs_ruby')

      @j_dea = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                               name: 'dea',
                               jobs: [@t_dea, @t_warden],
                               vm_type: vm_type_large,
                               stemcell: @stemcell_a)

      @j_router = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                                  name: 'router',
                                  jobs: [@t_nginx, @t_router, @t_warden],
                                  vm_type: vm_type_small,
                                  stemcell: @stemcell_b)

      @j_deps_ruby = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                                     name: 'needs_ruby',
                                     jobs: [@t_deps_ruby],
                                     vm_type: vm_type_small,
                                     stemcell: @stemcell_b)

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
      version, build = args[3][0..dot - 1], args[3][dot + 1..-1]

      package = Models::Package.find(name: name, version: version)
      expect(args[0]).to eq(package.blobstore_id)
      expect(args[1]).to eq(package.sha1)

      expect(args[4]).to be_a(Hash)

      {
        'result' => {
          'sha1' => "compiled #{package.id}",
          'blobstore_id' => "blob #{package.id}",
        },
      }
    end

    def compile_package_with_url_stub(args)
      request = args[0]
      dot = request['version'].rindex('.')
      version = request['version'][0..dot - 1]

      package = Models::Package.find(name: request['name'], version: version)
      expect(request['package_get_signed_url']).to eq("#{package.blobstore_id}-url")
      expect(request['upload_signed_url']).to eq('putcompiled_id-url')
      expect(request['digest']).to eq(package.sha1)

      request['deps'].each do |_, spec|
        expect(spec.keys).to include('package_get_signed_url')
      end
      {
        'result' => {
          'sha1' => "compiled #{package.id}",
        },
      }
    end

    def compile_package_with_url_encrypt_stub(args)
      request = args[0]
      dot = request['version'].rindex('.')
      version = request['version'][0..dot - 1]

      package = Models::Package.find(name: request['name'], version: version)
      expect(request['package_get_signed_url']).to eq("#{package.blobstore_id}-url")
      expect(request['upload_signed_url']).to eq('putcompiled_id-url')
      expect(request['digest']).to eq(package.sha1)
      expect(request['blobstore_headers']).to eq('encryption' => true)

      request['deps'].each do |_, spec|
        expect(spec.keys).to include('package_get_signed_url')
        expect(spec.keys).to include('blobstore_headers')
      end

      {
        'result' => {
          'sha1' => "compiled #{package.id}",
        },
      }
    end

    context 'when all needed packages are compiled' do
      let(:instance_groups_to_compile) { [@j_dea, @j_router] }

      it "doesn't perform any compilation" do
        prepare_samples

        [@p_dea, @p_syslog].each do |package|
          package.blobstore_id = nil
          package.sha1 = nil
          cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
          expect(@j_dea).to receive(:use_compiled_package).with(cp1)
          expect(compiler).not_to receive(:with_compile_lock)
            .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
        end

        [@p_router].each do |package|
          package.blobstore_id = nil
          package.sha1 = nil
          cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
          expect(@j_router).to receive(:use_compiled_package).with(cp1)
          expect(compiler).not_to receive(:with_compile_lock)
            .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
        end

        [@p_nginx, @p_warden].each do |package|
          package.blobstore_id = nil
          package.sha1 = nil
          cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
          expect(@j_dea).to receive(:use_compiled_package).with(cp1)
          expect(@j_router).to receive(:use_compiled_package).with(cp1)
          expect(compiler).not_to receive(:with_compile_lock)
            .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
        end

        compiler.perform
        # For @stemcell_a we need to compile:
        # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
        # For @stemcell_b:
        # [p_nginx, p_common, p_router, p_ruby, p_warden] = 5
        # But they are already compiled!
        expect(compiler.compilations_performed).to eq(0)

        expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_a.desc}'")
        expect(log_string).to include("Job templates 'cf-release/nginx', 'cf-release/router', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
      end
    end

    context 'when none of the packages are compiled' do
      let(:instance_groups_to_compile) { [@j_dea, @j_router] }

      it 'compiles all packages' do
        prepare_samples

        metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)

        allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, anything, { compiling: 'common' })
        expect(metadata_updater).to receive(:update_vm_metadata)
          .with(anything, anything, hash_including(:compiling)).exactly(10).times

        expect(vm_creator).to receive(:create_for_instance_plan).exactly(11).times

        agent_client = instance_double('Bosh::Director::AgentClient')
        allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
        expect(agent_client).to receive(:compile_package).exactly(11).times do |*args|
          compile_package_stub(args)
        end

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}", deployment.name).and_yield
        end

        @package_set_b.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times
        expect(@j_router).to receive(:use_compiled_package).exactly(5).times

        expect(instance_deleter).to receive(:delete_instance_plan).exactly(11).times

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

    context 'when url signing is enabled' do
      let(:instance_groups_to_compile) { [@j_dea, @j_router] }

      before do
        allow(blobstore).to receive(:encryption?)
        allow(blobstore).to receive(:can_sign_urls?).and_return(true)
        allow(blobstore).to receive(:generate_object_id).and_return('compiled_id')
        allow(blobstore).to receive(:sign) do |oid, verb|
          "#{verb}#{oid}-url"
        end
      end

      it 'compiles all packages' do
        prepare_samples

        metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)

        allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, anything, { compiling: 'common' })
        expect(metadata_updater).to receive(:update_vm_metadata)
          .with(anything, anything, hash_including(:compiling)).exactly(10).times

        expect(vm_creator).to receive(:create_for_instance_plan).exactly(11).times

        agent_client = instance_double('Bosh::Director::AgentClient')
        allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
        expect(agent_client).to receive(:compile_package_with_signed_url).exactly(11).times do |*args|
          compile_package_with_url_stub(args)
        end

        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock)
            .with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}", deployment.name)
            .and_yield
        end

        @package_set_b.each do |package|
          expect(compiler).to receive(:with_compile_lock)
            .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name)
            .and_yield
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times
        expect(@j_router).to receive(:use_compiled_package).exactly(5).times

        expect(instance_deleter).to receive(:delete_instance_plan).exactly(11).times

        compiler.perform
        expect(compiler.compilations_performed).to eq(11)

        @package_set_a.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end

        @package_set_b.each do |package|
          expect(package.compiled_packages.size).to be >= 1
        end
      end

      context 'with encrytion' do
        before do
          allow(blobstore).to receive(:signed_url_encryption_headers).and_return('encryption' => true)
          allow(blobstore).to receive(:encryption?).and_return(true)
        end

        it 'compiles all packages' do
          prepare_samples

          metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)

          allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
          expect(metadata_updater).to receive(:update_vm_metadata).with(anything, anything, { compiling: 'common' })
          expect(metadata_updater).to receive(:update_vm_metadata)
            .with(anything, anything, hash_including(:compiling)).exactly(10).times

          expect(vm_creator).to receive(:create_for_instance_plan).exactly(11).times

          agent_client = instance_double('Bosh::Director::AgentClient')
          allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
          expect(agent_client).to receive(:compile_package_with_signed_url).exactly(11).times do |*args|
            compile_package_with_url_encrypt_stub(args)
          end

          @package_set_a.each do |package|
            expect(compiler).to receive(:with_compile_lock)
              .with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}", deployment.name)
              .and_yield
          end

          @package_set_b.each do |package|
            expect(compiler).to receive(:with_compile_lock)
              .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name)
              .and_yield
          end

          expect(@j_dea).to receive(:use_compiled_package).exactly(6).times
          expect(@j_router).to receive(:use_compiled_package).exactly(5).times

          expect(instance_deleter).to receive(:delete_instance_plan).exactly(11).times

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
    end

    context 'when there are compiled packages with the same major version number but different patch number' do
      before do
        prepare_samples

        @j_dea = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                                 name: 'dea',
                                 jobs: [@t_dea, @t_warden],
                                 vm_type: @vm_type_large,
                                 stemcell: @stemcell_b)
      end

      context 'and we are using a source release' do
        it 'compiles all packages' do
          compiler = DeploymentPlan::Stages::PackageCompileStage.new(
            deployment.name,
            [@j_dea],
            compilation_config,
            compilation_instance_pool,
            release_manager,
            package_validator,
            compiled_package_finder,
            logger,
          )

          @package_set_a.each do |package|
            cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
            expect(@j_dea).not_to receive(:use_compiled_package).with(cp1)
            expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
          end

          expect(vm_creator).to receive(:create_for_instance_plan).exactly(6).times do |instance_plan|
            # metadata_updater is called for every package compilation, and it expects there to be an active_vm
            instance_plan.instance.model.active_vm = Models::Vm.make(cid: instance_plan.instance.model.id, instance: instance_plan.instance.model)
          end

          agent_client = instance_double('Bosh::Director::AgentClient')
          allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
          expect(agent_client).to receive(:compile_package).exactly(6).times do |*args|
            compile_package_stub(args)
          end

          compiler.perform
          # For @stemcell_b we need to compile:
          # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
          # and they should be recompiled
          expect(compiler.compilations_performed).to eq(6)

          expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
        end
      end

      context 'and we are using a compiled release' do
        it 'does not compile any packages' do
          compiler = DeploymentPlan::Stages::PackageCompileStage.new(
            deployment.name,
            [@j_dea],
            compilation_config,
            compilation_instance_pool,
            release_manager,
            package_validator,
            compiled_package_finder,
            logger,
          )

          @j_dea.jobs.each do |job|
            job.package_models.each do |package|
              package.blobstore_id = nil
              package.sha1 = nil
              cp1 = make_compiled(release_version_model, package, @stemcell_a.models.first)
              expect(@j_dea).to receive(:use_compiled_package).with(cp1)
              expect(compiler).not_to receive(:with_compile_lock)
                .with(package.id, "#{@stemcell_b.os}/#{@stemcell_b.version}", deployment.name).and_yield
            end
          end

          compiler.perform
          # For @stemcell_b we need to compile:
          # [p_dea, p_nginx, p_syslog, p_warden, p_common, p_ruby] = 6
          # and they should be recompiled
          expect(compiler.compilations_performed).to eq(0)

          expect(log_string).to include("Job templates 'cf-release/dea', 'cf-release/warden' need to run on stemcell '#{@stemcell_b.desc}'")
        end
      end
    end

    context 'when there are compiled packages that do not have a blobstore id and compiled against a different stemcell version' do
      let(:invalid_package) { Models::Package.make(sha1: nil, blobstore_id: nil) }

      before do
        prepare_samples

        release_version_model.add_package(invalid_package)

        @t_dea = instance_double(
          'Bosh::Director::DeploymentPlan::Job',
          release: @release, package_models: [@p_dea, @p_nginx, @p_syslog, invalid_package], name: 'dea',
        )

        @j_dea = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                                 name: 'dea',
                                 jobs: [@t_dea, @t_warden],
                                 vm_type: @vm_type_large,
                                 stemcell: @stemcell_b)
      end

      context 'and we are using a compiled release' do
        let(:instance_groups_to_compile) { [@j_dea] }

        it 'does not compile any packages' do
          expect { compiler.perform }.to raise_error PackageMissingSourceCode
        end
      end
    end

    context 'compiling packages with transitive dependencies' do
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:instance_groups_to_compile) { [@j_deps_ruby] }
      let(:vm_cid) { 'vm-cid-0' }

      before do
        prepare_samples

        metadata_updater = instance_double('Bosh::Director::MetadataUpdater', update_vm_metadata: nil)
        allow(Bosh::Director::MetadataUpdater).to receive_messages(build: metadata_updater)
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, anything, hash_including(:compiling))

        initial_state = {
          'deployment' => 'mycloud',
          'vm_type' => {},
          'stemcell' => {},
          'networks' => net,
        }

        allow(AgentClient).to receive(:with_agent_id).and_return(agent)
        allow(agent).to receive(:wait_until_ready)
        allow(agent).to receive(:update_settings)
        allow(agent).to receive(:apply).with(initial_state)
        allow(agent).to receive(:compile_package) do |*args|
          name = args[2]
          {
            'result' => {
              'sha1' => "compiled.#{name}.sha1",
              'blobstore_id' => "blob.#{name}.id",
            },
          }
        end

        allow(compiler).to receive(:with_compile_lock).and_yield
        allow(vm_creator).to receive(:create_for_instance_plan)
      end

      it 'sends information about immediate dependencies of the package being compiled' do
        expect(agent).to receive(:compile_package).with(
          anything, # source package blobstore id
          anything, # source package sha1
          'common', # package name
          '0.1-dev.1', # package version
          {}
        ).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
          anything, # source package blobstore id
          anything, # source package sha1
          'ruby', # package name
          '0.1-dev.1', # package version
          {
            'common' => {
              'name' => 'common',
              'version' => '0.1-dev.1',
              'sha1' => 'compiled.common.sha1',
              'blobstore_id' => 'blob.common.id',
            },
          },
        ).ordered # immediate dependencies
        expect(agent).to receive(:compile_package).with(
          anything, # source package blobstore id
          anything, # source package sha1
          'needs_ruby', # package name
          '0.1-dev.1', # package version
          {
            'ruby' => {
              'name' => 'ruby',
              'version' => '0.1-dev.1',
              'sha1' => 'compiled.ruby.sha1',
              'blobstore_id' => 'blob.ruby.id',
            },
          },
        ).ordered # immediate dependencies

        allow(@j_deps_ruby).to receive(:use_compiled_package)

        compiler.perform
      end
    end

    context 'when the deploy is cancelled' do
      let(:release_version_model) { Models::ReleaseVersion.make }
      let(:stemcell) { make_stemcell }
      let(:instance_groups_to_compile) { [instance_group] }

      let(:release_version) do
        instance_double(
          'Bosh::Director::DeploymentPlan::ReleaseVersion',
          name: 'release_name',
          model: release_version_model,
          version: release_version_model.version,
          exported_from: [],
        )
      end

      let(:instance_group) do
        instance_double(
          'Bosh::Director::DeploymentPlan::InstanceGroup',
          name: 'job_name',
          stemcell: stemcell,
        )
      end

      before do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef')
        release = Models::Release.make(name: release_version.name)
        release.add_version(release_version_model)
        package_model = Models::Package.make(name: 'foobarbaz', dependency_set: [], fingerprint: 'deadbeef', blobstore_id: 'fake_id')
        job = instance_double('Bosh::Director::DeploymentPlan::Job', release: release_version, package_models: [package_model], name: 'fake_template')
        allow(instance_group).to receive_messages(jobs: [job])
      end

      it 'cancels the compilation' do
        vm_cid = 'vm-cid-1'
        event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
        allow(event_log_stage).to receive(:advance_and_track).with(anything).and_yield

        agent = instance_double('Bosh::Director::AgentClient')

        expect(cloud).to receive(:create_vm).once.ordered
          .with(instance_of(String), stemcell.models.first.cid, {}, net, [], { 'bosh' => { 'group' => 'fake-director-name-mycloud-compilation-deadbeef', 'groups' => expected_groups } })
          .and_return(vm_cid)

        allow(AgentClient).to receive(:with_agent_id).and_return(agent)

        expect(agent).to receive(:wait_until_ready).ordered
        expect(agent).to receive(:update_settings).ordered
        expect(agent).to receive(:apply).with(initial_state).ordered
        expect(agent).to receive(:get_state).and_return('agent-state' => 'yes').ordered
        expect(agent).to receive(:compile_package).and_raise(TaskCancelled).ordered

        expect do
          compiler.perform
        end.to raise_error(TaskCancelled)
      end

      # this can happen when the cancellation comes in when there is a package to be compiled,
      # and the compilation is not even in-flight. e.g.
      # - you have 3 compilation workers, but you've got 5 packages to compile; or
      # - package "bar" depends on "foo", deploy is cancelled when compiling "foo" ("bar" is blocked)
      context 'when there is a pending compilation' do
        let(:reuse_compilation_vms) { true }
        let(:number_of_workers) { 1 }
        it 'cancels the compilation' do
          allow(Config).to receive(:job_cancelled?).and_raise(TaskCancelled)
          event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
          allow(event_log_stage).to receive(:advance_and_track).with(anything).and_yield

          expect do
            compiler.perform
          end.not_to raise_error
        end
      end
    end

    describe 'with reuse_compilation_vms option set' do
      let(:reuse_compilation_vms) { true }
      let(:instance_groups_to_compile) { [@j_dea] }

      before { allow(SecureRandom).to receive(:uuid).and_return('deadbeef') }

      let(:vm_creator) do
        Bosh::Director::VmCreator.new(logger, template_blob_cache, dns_encoder, agent_broadcaster, plan.link_provider_intents)
      end

      it 'reuses compilation VMs' do
        prepare_samples

        expect(vm_creator).to receive(:create_for_instance_plan).exactly(1).times do |instance_plan|
          # metadata_updater is called for every package compilation, and it expects there to be an active_vm
          instance_plan.instance.model.active_vm = Models::Vm.make(cid: instance_plan.instance.model.id, instance: instance_plan.instance.model)
        end

        agent_client = instance_double('BD::AgentClient')
        allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)

        expect(agent_client).to receive(:compile_package).exactly(6).times do |*args|
          name = args[2]
          dot = args[3].rindex('.')
          version, = args[3][0..dot - 1], args[3][dot + 1..-1]

          package = Models::Package.find(name: name, version: version)
          expect(args[0]).to eq(package.blobstore_id)
          expect(args[1]).to eq(package.sha1)

          expect(args[4]).to be_a(Hash)

          {
            'result' => {
              'sha1' => "compiled #{package.id}",
              'blobstore_id' => "blob #{package.id}",
            },
          }
        end

        expect(@j_dea).to receive(:use_compiled_package).exactly(6).times

        expect(instance_deleter).to receive(:delete_instance_plan)
        @package_set_a.each do |package|
          expect(compiler).to receive(:with_compile_lock).with(package.id, "#{@stemcell_a.os}/#{@stemcell_a.version}", deployment.name).and_yield
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

        expect(cloud).to receive(:create_vm)
          .with(instance_of(String), @stemcell_a.models.first.cid, {}, net, [], { 'bosh' => { 'group' => 'fake-director-name-mycloud-compilation-deadbeef', 'groups' => expected_groups } })
          .and_return(vm_cid)

        allow(AgentClient).to receive(:with_agent_id).and_return(agent)

        expect(agent).to receive(:wait_until_ready)
        expect(agent).to receive(:update_settings)
        expect(agent).to receive(:apply).with(initial_state)
        expect(agent).to receive(:get_state).and_return('agent-state' => 'yes')
        expect(agent).to receive(:compile_package).and_raise(RuntimeError)

        allow(compiler).to receive(:with_compile_lock).and_yield

        expect do
          compiler.perform
        end.to raise_error(RuntimeError)
      end
    end

    it 'should make sure a parallel deployment did not compile a package already' do
      package = Models::Package.make
      stemcell = make_stemcell

      requirement = CompiledPackageRequirement.new(
        package: package,
        stemcell: stemcell,
        initial_instance_group: job,
        dependency_key: 'fake-dependency-key',
        cache_key: 'fake-cache-key',
        compiled_package: nil,
      )

      fake_compiled_package = instance_double('Bosh::Director::Models::CompiledPackage', name: 'fake')
      expect(compiled_package_finder).to receive(:find_compiled_package).and_return(fake_compiled_package)

      allow(compiler).to receive(:with_compile_lock).with(package.id, "#{stemcell.os}/#{stemcell.version}", deployment.name).and_yield
      compiler.compile_package(requirement)

      expect(requirement.compiled_package).to eq(fake_compiled_package)
    end

    describe '#prepare_vm' do
      let(:package) { Models::Package.make }
      let(:number_of_workers) { 2 }
      let(:plan) do
        deployment_model = Models::Deployment.make
        Bosh::Director::Models::VariableSet.make(deployment: deployment_model)

        instance_double('Bosh::Director::DeploymentPlan::Planner',
                        compilation: compilation_config,
                        model: deployment_model,
                        name: 'fake-deployment',
                        ip_provider: ip_provider,
                        tags: {},
                        link_provider_intents: [])
      end
      let(:stemcell) { make_stemcell(cid: 'stemcell-cid') }
      let(:instance) { instance_double(DeploymentPlan::Instance) }

      context 'with reuse_compilation_vms' do
        let(:reuse_compilation_vms) { true }
        let(:network) { instance_double('Bosh::Director::DeploymentPlan::ManualNetwork', name: 'default', network_settings: nil) }
        let(:instance_reuser) { instance_double('Bosh::Director::InstanceReuser') }
        let(:number_of_workers) { 4 }
        let(:instance_groups_to_compile) { [] }

        before do
          allow(plan).to receive(:network).with('default').and_return(network)
        end

        it 'should clean up the compilation vm if it failed' do
          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(RpcTimeout)

          allow(instance_reuser).to receive_messages(get_instance: nil)
          allow(instance_reuser).to receive_messages(get_num_instances: 0)
          allow(instance_reuser).to receive(:add_in_use_instance)
          allow(instance_reuser).to receive(:total_instance_count).and_return(3)
          allow(ip_provider).to receive(:reserve).with(instance_of(Bosh::Director::DesiredNetworkReservation))

          expect(instance_reuser).to receive(:remove_instance).ordered
          expect(instance_deleter).to receive(:delete_instance_plan).ordered
          allow(ip_provider).to receive(:release)

          expect do
            compiler.prepare_vm(stemcell, package) do
              # nothing
            end
          end.to raise_error RpcTimeout
        end
      end

      describe 'trusted certificate handling' do
        let(:instance_groups_to_compile) { [] }

        let(:client) { instance_double('Bosh::Director::AgentClient') }

        before do
          Bosh::Director::Config.trusted_certs = DIRECTOR_TEST_CERTS

          allow(cloud).to receive(:create_vm).and_return('new-vm-cid')
          allow(AgentClient).to receive_messages(with_agent_id: client)
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
              compiler.prepare_vm(stemcell, package) {}
            rescue exception
            end

            expect(Models::Vm.find(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1)).to be_nil
          end
        end

        it 'should update the database with the new VM' 's trusted certs' do
          expect do
            compiler.prepare_vm(stemcell, package) {}
          end.to change {
            matching_vm = Models::Vm.find(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1)
            matching_vm.nil? ? 0 : Models::Instance.all.select { |i| i.active_vm == matching_vm }.count
          }.from(0).to(1)
        end

        context 'when the new vm fails to start' do
          it_should_not_update_db(:wait_until_ready, RpcTimeout)
        end

        context 'when task was cancelled' do
          it_should_not_update_db(:wait_until_ready, TaskCancelled)
        end

        context 'when the update_settings method fails' do
          it_should_not_update_db(:update_settings, RpcTimeout)
        end
      end
    end
  end
end
