require 'spec_helper'

module Bosh::Director
  describe Jobs::RunErrand do
    subject(:job) { described_class.new('fake-dep-name', errand_name, keep_alive, when_changed, []) }

    let(:keep_alive) { false }
    let(:when_changed) { false }
    let(:task_result) { Bosh::Director::TaskDBWriter.new(:result_output, task.id) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}
    let(:thread_pool) { double(Bosh::ThreadPool) }
    let(:instances) { [instance_double(Bosh::Director::Models::Instance, uuid: 'instance-uuid')] }
    let(:template_blob_cache) { instance_double('Bosh::Director::Core::Templates::TemplateBlobCache') }
    let(:instance_manager) { instance_double(Bosh::Director::Api::InstanceManager) }

    before do
      allow(Api::InstanceManager).to receive(:new).and_return(instance_manager)
      allow(instance_manager).to receive(:find_instances_by_deployment).and_return(instances)

      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(Config).to receive(:record_events).and_return(true)
      allow(Config).to receive(:event_log).and_return(event_log)
      allow(Config).to receive(:result).and_return(task_result)
      allow(Config).to receive(:current_job).and_return(job)
      allow(Bosh::ThreadPool).to receive(:new).and_return(thread_pool)
      allow(JobRenderer).to receive(:render_job_instances_with_cache).with(anything, template_blob_cache, anything, logger)
      allow(template_blob_cache).to receive(:clean_cache!)

      allow(thread_pool).to receive(:wrap) do |&blk|
        blk.call(thread_pool) if blk
      end
      allow(thread_pool).to receive(:process).and_yield
    end

    let(:task) { Bosh::Director::Models::Task.make(:id => 42, :username => 'user') }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      manifest_hash['name'] = 'fake-dep-name'
      manifest_hash
    end
    let(:service_errand_manifest_hash) do
      service_errand_manifest_hash = Bosh::Spec::NewDeployments.manifest_with_errand_on_service_instance
      service_errand_manifest_hash['name'] = 'fake-dep-name'
      service_errand_manifest_hash
    end

    let(:agent_run_errand_result) do
      {
        'exit_code' => 0,
        'stdout' => 'fake-stdout',
        'stderr' => 'fake-stderr',
      }
    end
    let(:instance) { instance_double(DeploymentPlan::Instance, uuid: 'instance-uuid', job_name: 'instance-group') }

    let(:errand_result) { Errand::Result.from_agent_task_results(instance, errand_name, agent_run_errand_result, nil) }

    describe 'DJ job class expectations' do
      let(:job_type) { :run_errand }
      let(:queue) { :normal }
      let(:errand_name) {'fake-errand-name'}

      it_behaves_like 'a DJ job'
    end

    context 'when running an errand on a lifecycle service instance by release job name' do
      let(:errand_name) {'errand1'}

      describe '#perform' do
        let!(:deployment_model) do
          deployment = Models::Deployment.make(
            name: 'fake-dep-name',
            manifest: YAML.dump(service_errand_manifest_hash),
          )
          deployment.cloud_configs = [cloud_config]
          deployment
        end

        let(:deployment_planner_factory) { instance_double('Bosh::Director::DeploymentPlan::PlannerFactory', create_from_model: planner) }

        before do
          allow(DeploymentPlan::PlannerFactory).to receive(:new).
            and_return(deployment_planner_factory)

          allow(job).to receive(:task_id).and_return(task.id)
          allow(Errand::Runner).to receive(:new).and_return(runner)

          allow(DeploymentPlan::Assembler).to receive(:create).with(planner).and_return(assembler)
        end

        let(:planner) do
          ip_repo = DeploymentPlan::DatabaseIpRepo.new(logger)
          ip_provider = DeploymentPlan::IpProvider.new(ip_repo, {}, logger)

          instance_double(
            'Bosh::Director::DeploymentPlan::Planner',
            ip_provider: ip_provider,
            template_blob_cache: template_blob_cache,
            instance_groups: [errand_instance_group],
            availability_zones: [],
            use_short_dns_addresses?: false,
            instance_group: nil,
            model: deployment_model,
          )
        end

        let(:instance_model) { Models::Instance.make(job: 'errand1', uuid: 'instance-uuid') }
        let(:errand_instance_group) do
          instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
            instances: [instance],
            is_errand?: false,
            jobs: [errand_job],
            bind_instances: nil,
          )
        end

        let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model, uuid: 'instance-uuid', configuration_hash: 'hash', current_packages: {}, current_job_state: {}) }

        let(:assembler) { instance_double(DeploymentPlan::Assembler, bind_models: nil) }

        let(:errand_job){ instance_double('Bosh::Director::DeploymentPlan::Job', name: 'errand1', runs_as_errand?: true )}
        let(:cloud_config) { Models::Config.make(:cloud) }
        let(:runner) { instance_double('Bosh::Director::Errand::Runner') }
        let(:errand_result) { Errand::Result.new(instance, errand_name, 0, nil, nil, nil) }

        it 'runs the specified errand job on the found service instance' do
          expect(Errand::Runner).to receive(:new).
            with('errand1', true, task_result, instance_manager, be_a(Bosh::Director::LogsFetcher)).
            and_return(runner)
          expect(runner).to receive(:run).and_return(errand_result)
          subject.perform
        end
      end
    end

    context 'when running an errand on a lifecycle errand instance by instance group name' do
      let(:errand_name) {'fake-errand-name'}

      describe '#perform' do
        context 'when deployment exists' do
          let!(:deployment_model) do
            deployment = Models::Deployment.make(
              name: 'fake-dep-name',
              manifest: YAML.dump(manifest_hash),
            )
            deployment.cloud_configs = [cloud_config]
            deployment
          end

          before do
            allow(DeploymentPlan::PlannerFactory).to receive(:new).
              and_return(instance_double(
                'Bosh::Director::DeploymentPlan::PlannerFactory',
                create_from_model: planner,
              ))
            allow(job).to receive(:task_id).and_return(task.id)

            allow(DeploymentPlan::Assembler).to receive(:create).and_return(assembler)
          end

          let(:assembler) { instance_double(DeploymentPlan::Assembler, bind_models: nil) }

          let(:planner) do
            ip_repo = DeploymentPlan::DatabaseIpRepo.new(logger)
            ip_provider = DeploymentPlan::IpProvider.new(ip_repo, {}, logger)

          instance_double(
            'Bosh::Director::DeploymentPlan::Planner',
            ip_provider: ip_provider,
            template_blob_cache: template_blob_cache,
            instance_groups: [],
            availability_zones: [],
            use_short_dns_addresses?: false,
            model: deployment_model,
          )
        end
        let(:compile_packages_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep, perform: nil) }
        let(:cloud_config) { Models::Config.make(:cloud) }
        let(:runner) { instance_double('Bosh::Director::Errand::Runner') }

        before do
          allow(template_blob_cache).to receive(:clean_cache!)
          allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).with(planner).and_return(compile_packages_step)
        end

          context 'when instance group representing an errand exists' do
            let(:deployment_instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-errand-name', needed_instance_plans: []) }
            before { allow(planner).to receive(:instance_group).with('fake-errand-name').and_return(deployment_instance_group) }

            context 'when instance group can run as an errand (usually means lifecycle: errand)' do
              before { allow(deployment_instance_group).to receive(:is_errand?).and_return(true) }
              before { allow(deployment_instance_group).to receive(:bind_instances) }

              context 'when instance group has at least 1 instance' do
                before { allow(deployment_instance_group).to receive(:instances).with(no_args).and_return([instance]) }
                let(:instance_model) { Models::Instance.make(job: 'foo-job', uuid: 'instance-uuid') }
                let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model, to_s: 'foo-job/instance-uuid', uuid: 'instance-uuid', configuration_hash: 'hash', current_packages: {}) }

                before { allow(Lock).to receive(:new).with('lock:deployment:fake-dep-name', {timeout: 10, deployment_name: 'fake-dep-name'}).and_return(lock) }

                let(:lock) { instance_double('Bosh::Director::Lock') }

                before { allow(lock).to receive(:lock).and_yield }

                before do
                  allow(LogBundlesCleaner).to receive(:new).
                    with(blobstore, 86400 * 10, logger).
                    and_return(log_bundles_cleaner)
                end
                let(:log_bundles_cleaner) do
                  instance_double('Bosh::Director::LogBundlesCleaner', {
                    register_blobstore_id: nil,
                    clean: nil,
                  })
                end

                before do
                  allow(LogsFetcher).to receive(:new).
                    with(instance_manager, log_bundles_cleaner, logger).
                    and_return(logs_fetcher)
                end
                let(:logs_fetcher) { instance_double('Bosh::Director::LogsFetcher') }

                before do
                  allow(Errand::InstanceGroupManager).to receive(:new).
                    with(planner, deployment_instance_group, logger).
                    and_return(instance_group_manager)
                end
                let(:instance_group_manager) do
                  instance_double('Bosh::Director::Errand::InstanceGroupManager', {
                    update_instances: nil,
                    delete_vms: nil,
                    create_missing_vms: nil,
                  })
                end

                before do
                  allow(Errand::Runner).to receive(:new).
                    with('fake-errand-name', false, task_result, instance_manager, logs_fetcher).
                    and_return(runner)
                end
                let(:runner) { instance_double('Bosh::Director::Errand::Runner') }
                before do
                  allow(runner).to receive(:run).
                    with(instance).
                    and_return(errand_result)
                end

                it 'binds models, validates packages, compiles packages' do
                  expect(assembler).to receive(:bind_models)
                  expect(compile_packages_step).to receive(:perform)

                  subject.perform
                end

                describe 'locking' do
                  let(:lock_helper) { instance_double(LockHelperImpl) }
                  it 'runs an errand with deployment lock and returns short result description' do
                    called_after_block_check = double(:called_in_block_check, call: nil)

                    allow(LockHelperImpl).to receive(:new).and_return(lock_helper)

                    expect(lock_helper).to receive(:with_deployment_lock) do |deployment, &blk|
                      result = blk.call
                      called_after_block_check.call
                      result
                    end

                    expect(deployment_instance_group).to receive(:bind_instances)

                    expect(instance_group_manager).to receive(:create_missing_vms).with(no_args).ordered

                    expect(instance_group_manager).to receive(:update_instances).with(no_args).ordered

                    expect(runner).to receive(:run).
                      with(instance).
                      ordered.
                      and_return(errand_result)

                    expect(instance_group_manager).to receive(:delete_vms).with(no_args).ordered

                    expect(template_blob_cache).to receive(:clean_cache!).ordered

                    expect(called_after_block_check).to receive(:call).ordered

                    expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                  end
                end

                context 'when the errand fails to run' do
                  it 'cleans up the vms anyway' do
                    error = Exception.new
                    allow(instance_group_manager).to receive(:create_missing_vms).with(no_args).ordered
                    expect(runner).to receive(:run).with(instance).and_raise(error)
                    expect(instance_group_manager).to receive(:delete_vms).with(no_args).ordered

                    expect { subject.perform }.to raise_error(error)
                  end

                  context 'when cleanup fails' do
                    it 'raises the original exception and warns about the clean up failure' do
                      original_error = Exception.new('original error')
                      cleanup_error = Exception.new('cleanup error')
                      expect(runner).to receive(:run).with(instance).and_raise(original_error)
                      expect(instance_group_manager).to receive(:delete_vms).with(no_args).ordered.and_raise(cleanup_error)

                      expect { subject.perform }.to raise_error(original_error)
                      expect(log_string).to include('cleanup error')
                    end
                  end
                end

                context 'when the errand runs but cleanup fails' do
                  it 'raises clean up error' do
                    cleanup_error = Exception.new('cleanup error')
                    expect(runner).to receive(:run).with(instance)
                    expect(instance_group_manager).to receive(:delete_vms).with(no_args).ordered.and_raise(cleanup_error)

                    expect { subject.perform }.to raise_error(cleanup_error)
                  end
                end

                context 'when errand is run with keep-alive' do
                  let(:keep_alive) { true }

                  it 'does not delete instances' do
                    expect(instance_group_manager).to_not receive(:delete_vms)

                    expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                  end
                end

              context 'when errand is run with when-changed' do
                before do
                  allow(JobRenderer).to receive(:render_job_instances_with_cache).with([instance_plan], template_blob_cache, anything, logger)
                  allow(deployment_instance_group).to receive(:needed_instance_plans).and_return([instance_plan])
                end

                  let(:when_changed) { true }
                  let(:instance_model) { Models::Instance.make }
                  context 'when errand has been run before' do
                    let!(:errand_model) do
                      Models::ErrandRun.make(
                        deployment: deployment_model,
                        errand_name: errand_name,
                        successful_state_hash: successful_state_hash,
                      )
                    end
                    let(:single_errand_state_hash) { ::Digest::SHA1.hexdigest('instance-uuid' + successful_configuration_hash + successful_packages_spec.to_s) }
                    let(:successful_state_hash) { ::Digest::SHA1.hexdigest(single_errand_state_hash) }

                    context 'when errand succeeded on the previous run' do
                      context 'when the errand configuration has NOT changed' do
                        let(:successful_configuration_hash) { 'last_successful_config' }
                        let(:successful_packages_spec) { {'packages' => 'last_successful_packages'} }

                        before do
                          allow(instance).to receive(:current_packages).and_return(successful_packages_spec)
                          allow(instance).to receive(:configuration_hash).and_return(successful_configuration_hash)
                        end
                        let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }

                        it 'does not run the errand' do
                          expect(instance_group_manager).to_not receive(:create_missing_vms)
                          expect(runner).to_not receive(:run)

                          expect(subject.perform).to eq('skipped - no changes detected')
                        end
                      end

                      context 'when the errand packages has changed' do
                        let(:successful_configuration_hash) { 'last_successful_config' }
                        let(:successful_packages_spec) { 'last_successful_packages' }

                        let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }
                        before do
                          allow(instance).to receive(:current_packages).and_return({'packages' => 'new_packages'})
                          allow(instance).to receive(:configuration_hash).and_return(successful_configuration_hash)
                        end

                        it 'runs the errands' do
                          expect(instance_group_manager).to receive(:create_missing_vms)
                          expect(runner).to receive(:run)

                          expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                        end
                      end

                      context 'when the errand configuration has changed' do
                        let(:successful_configuration_hash) { 'last_successful_config' }
                        let(:successful_packages_spec) { 'last_successful_packages' }

                        let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }
                        before do
                          allow(instance).to receive(:current_packages).and_return(successful_packages_spec)
                          allow(instance).to receive(:configuration_hash).and_return('new_config')
                        end

                        it 'runs the errands' do
                          expect(instance_group_manager).to receive(:create_missing_vms)
                          expect(runner).to receive(:run)

                          expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                        end
                      end
                    end

                    context 'when errand failed on the previous run' do
                      let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }
                      let(:successful_configuration_hash) { '' }
                      let(:successful_packages_spec) { '' }

                      context 'when the errand configuration has NOT changed' do
                        before do
                          allow(instance).to receive(:current_packages).and_return({})
                          allow(instance).to receive(:configuration_hash).and_return('')
                        end

                        it 'runs the errand' do
                          expect(instance_group_manager).to receive(:create_missing_vms)
                          expect(runner).to receive(:run)

                          expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                        end
                      end

                      context 'when the errand configuration has changed' do
                        before do
                          allow(instance).to receive(:current_packages).and_return({'packages' => 'new_packages'})
                          allow(instance).to receive(:configuration_hash).and_return('new_config')
                        end

                        it 'runs the errands' do
                          expect(instance_group_manager).to receive(:create_missing_vms)
                          expect(runner).to receive(:run)

                          expect(subject.perform).to eq('1 succeeded, 0 errored, 0 canceled')
                        end
                      end
                    end
                  end

                  context 'when errand has never been run before' do
                    let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }

                    it 'always runs the errand' do
                      allow(instance).to receive(:current_packages).and_return({'packages' => 'successful_packages_spec'})
                      allow(instance).to receive(:configuration_hash).and_return('successful_configuration_hash')

                      expect(instance_group_manager).to receive(:create_missing_vms)
                      expect(runner).to receive(:run)

                      subject.perform
                    end
                  end
                end
              end

              context 'when instance group representing an errand has 0 instances' do
                before { allow(deployment_instance_group).to receive(:instances).with(no_args).and_return([]) }

                it 'raises an error because errand cannot be run on a job with 0 instances' do
                  expect {
                    subject.perform
                  }.to raise_error(InstanceNotFound, %r{fake-errand-name/0.*doesn't exist})
                end
              end
            end

            context "when instance group cannot run as an errand" do
              before { allow(deployment_instance_group).to receive(:is_errand?).and_return(false) }

              it 'raises an error because non-errand jobs cannot be used with run errand cmd' do
                expect {
                  subject.perform
                }.to raise_error(RunErrandError, /Instance group 'fake-errand-name' is not an errand/)
              end
            end
          end

          context 'when instance group representing an errand does not exist' do
            before { allow(planner).to receive(:instance_group).with('fake-errand-name').and_return(nil) }

            it 'raises an error because user asked to run an unknown errand' do
              expect {
                subject.perform
              }.to raise_error(JobNotFound, %r{fake-errand-name.*doesn't exist})
            end
          end
        end
      end

      describe '#task_checkpoint' do
        context 'shared checkpoint behavior' do
          subject { job.task_checkpoint }
          it_behaves_like 'raising an error when a task has timed out or been canceled'
        end

        context 'when the errand indicates that cancellation should be ignored even though the task is timed out or canceled' do
          let(:errand) { instance_double(Errand::LifecycleErrandStep, prepare: nil, run: [], ignore_cancellation?: true) }
          let(:errand_provider) { instance_double(Errand::ErrandProvider, get: errand) }
          let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }
          let(:task) { instance_double('Bosh::Director::Models::Task', id: 42, state: 'cancelling', username: 'username' ) }

          before do
            allow(Errand::DeploymentPlannerProvider).to receive(:new)
            allow(Errand::ErrandProvider).to receive(:new).and_return(errand_provider)
            allow(Bosh::Director::Api::TaskManager).to receive(:new).and_return(task_manager)
            subject.task_id = 42
          end

          it 'should not respond true to task_cancelled?' do
            subject.perform
            expect(subject.task_cancelled?).to eq(false)
          end
        end
      end
    end
  end
end
