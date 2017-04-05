require 'spec_helper'

module Bosh::Director
  describe Jobs::RunErrand do
    subject(:job) { described_class.new('fake-dep-name', 'fake-errand-name', keep_alive, when_changed) }
    let(:keep_alive) { false }
    let(:when_changed) { false }
    let(:task_result) { Bosh::Director::TaskDBWriter.new(:result_output, task.id) }
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}

    before do
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(Config).to receive(:record_events).and_return(true)
      allow(job).to receive(:event_manager).and_return(event_manager)
      allow(Config).to receive(:current_job).and_return(job)
      allow(Config).to receive(:event_log).and_return(event_log)
      allow(Config).to receive(:result).and_return(task_result)
    end

    let(:task) { Bosh::Director::Models::Task.make(:id => 42, :username => 'user') }
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      manifest_hash['name'] = 'fake-dep-name'
      manifest_hash
    end

    let(:agent_run_errand_result) do
      {
        'exit_code' => 0,
        'stdout' => 'fake-stdout',
        'stderr' => 'fake-stderr',
      }
    end

    let(:errand_result) { Errand::Result.from_agent_task_results(agent_run_errand_result, nil) }

    describe 'DJ job class expectations' do
      let(:job_type) { :run_errand }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      context 'when deployment exists' do
        let!(:deployment_model) do
          Models::Deployment.make(
            name: 'fake-dep-name',
            manifest: YAML.dump(manifest_hash),
            cloud_config: cloud_config
          )
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
            job_renderer: job_renderer,
          )
        end
        let(:compile_packages_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep, perform: nil) }
        let(:job_renderer) { JobRenderer.create.tap { |jr| allow(jr).to receive(:render_job_instances) } }

        let(:cloud_config) { Models::CloudConfig.make }

        before { allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).with(planner).and_return(compile_packages_step) }

        context 'when job representing an errand exists' do
          let(:deployment_job) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-errand-name', needed_instance_plans: []) }
          before { allow(planner).to receive(:instance_group).with('fake-errand-name').and_return(deployment_job) }

          context 'when job can run as an errand (usually means lifecycle: errand)' do
            before { allow(deployment_job).to receive(:is_errand?).and_return(true) }
            before { allow(deployment_job).to receive(:bind_instances) }

            context 'when job has at least 1 instance' do
              before { allow(deployment_job).to receive(:instances).with(no_args).and_return([instance]) }
              let(:instance_model) { Models::Instance.make(job: 'foo-job', uuid: 'instance_id') }
              let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model) }

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
                  with(be_a(Api::InstanceManager), log_bundles_cleaner, logger).
                  and_return(logs_fetcher)
              end
              let(:logs_fetcher) { instance_double('Bosh::Director::LogsFetcher') }

              before do
                allow(Errand::JobManager).to receive(:new).
                  with(planner, deployment_job, logger).
                  and_return(job_manager)
              end
              let(:job_manager) do
                instance_double('Bosh::Director::Errand::JobManager', {
                  update_instances: nil,
                  delete_vms: nil,
                  create_missing_vms: nil,
                })
              end

              before do
                allow(Errand::Runner).to receive(:new).
                  with(instance, 'fake-errand-name', task_result, be_a(Api::InstanceManager), be_a(Bosh::Director::LogsFetcher)).
                  and_return(runner)
              end
              let(:runner) { instance_double('Bosh::Director::Errand::Runner') }
              before do
                allow(runner).to receive(:run).
                  with(no_args).
                  and_return(errand_result)
              end

              it 'binds models, validates packages, compiles packages' do
                expect(assembler).to receive(:bind_models)
                expect(compile_packages_step).to receive(:perform)

                subject.perform
              end

              it 'runs an errand with deployment lock and returns short result description' do
                called_after_block_check = double(:called_in_block_check, call: nil)
                expect(subject).to receive(:with_deployment_lock) do |deployment, &blk|
                  result = blk.call
                  called_after_block_check.call
                  result
                end

                expect(deployment_job).to receive(:bind_instances)

                expect(job_manager).to receive(:create_missing_vms).with(no_args).ordered

                expect(job_manager).to receive(:update_instances).with(no_args).ordered

                expect(runner).to receive(:run).
                  with(no_args).
                  ordered.
                  and_return(errand_result)

                expect(job_manager).to receive(:delete_vms).with(no_args).ordered

                expect(job_renderer).to receive(:clean_cache!).ordered

                expect(called_after_block_check).to receive(:call).ordered

                expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
              end

              it 'should store event' do
                subject.perform
                event_1 = Bosh::Director::Models::Event.first
                expect(event_1.user).to eq(task.username)
                expect(event_1.action).to eq('run')
                expect(event_1.object_type).to eq('errand')
                expect(event_1.object_name).to eq('fake-errand-name')
                expect(event_1.instance).to eq('foo-job/instance_id')
                expect(event_1.deployment).to eq('fake-dep-name')
                expect(event_1.task).to eq("#{task.id}")

                event_2 = Bosh::Director::Models::Event.all.last
                expect(event_2.parent_id).to eq(event_1.id)
                expect(event_2.user).to eq(task.username)
                expect(event_2.action).to eq('run')
                expect(event_2.object_type).to eq('errand')
                expect(event_2.object_name).to eq('fake-errand-name')
                expect(event_2.instance).to eq('foo-job/instance_id')
                expect(event_2.deployment).to eq('fake-dep-name')
                expect(event_2.context).to eq({"exit_code" => 0})
                expect(event_2.task).to eq("#{task.id}")
              end

              context 'when the errand fails to run' do
                let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }

                it 'cleans up the vms anyway' do
                  error = Exception.new
                  allow(job_manager).to receive(:create_missing_vms).with(no_args).ordered
                  expect(runner).to receive(:run).with(no_args).and_raise(error)
                  expect(job_manager).to receive(:delete_vms).with(no_args).ordered

                  expect { subject.perform }.to raise_error(error)
                end

                context 'when cleanup fails' do
                  it 'raises the original exception and warns about the clean up failure' do
                    original_error = Exception.new('original error')
                    cleanup_error = Exception.new('cleanup error')
                    expect(runner).to receive(:run).with(no_args).and_raise(original_error)
                    expect(job_manager).to receive(:delete_vms).with(no_args).ordered.and_raise(cleanup_error)

                    expect { subject.perform }.to raise_error(original_error)
                    expect(log_string).to include('cleanup error')
                  end
                end
              end

              context 'when the errand runs but cleanup fails' do
                it 'raises clean up error' do
                  cleanup_error = Exception.new('cleanup error')
                  expect(runner).to receive(:run).with(no_args)
                  expect(job_manager).to receive(:delete_vms).with(no_args).ordered.and_raise(cleanup_error)

                  expect { subject.perform }.to raise_error(cleanup_error)
                end
              end

              context 'when the errand is canceled' do
                before { allow(Api::TaskManager).to receive(:new).and_return(task_manager) }
                let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }

                before { allow(task).to receive(:state).and_return('cancelling') }

                context 'when agent is able to cancel run_errand task successfully' do
                  it 'cancels the errand, raises TaskCancelled, and cleans up errand VMs' do
                    expect(job_manager).to receive(:create_missing_vms).with(no_args).ordered
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered
                    expect(job_manager).to receive(:delete_vms).with(no_args).ordered

                    expect { subject.perform }.to raise_error(TaskCancelled)
                    event_2 = Bosh::Director::Models::Event.all.last
                    expect(event_2.error).to eq("Task 42 cancelled")
                  end

                  it 'does not allow cancellation while cleaning up errand VMs' do
                    expect(job_manager).to receive(:create_missing_vms).with(no_args).ordered
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered
                    expect(job_manager).to(receive(:delete_vms).with(no_args).ordered) { job.task_checkpoint }

                    expect { subject.perform }.to raise_error(TaskCancelled)
                  end
                end

                context 'when the agent throws an exception while cancelling run_errand task' do
                  it 'raises RpcRemoteException and cleans up errand VMs' do
                    error = RpcRemoteException.new
                    expect(job_manager).to receive(:create_missing_vms).with(no_args).ordered
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered.and_raise(error)
                    expect(job_manager).to receive(:delete_vms).with(no_args).ordered

                    expect { subject.perform }.to raise_error(error)
                  end
                end
              end

              context 'when errand is run with keep-alive' do
                let(:keep_alive) { true }

                it 'does not delete instances' do
                  expect(job_manager).to_not receive(:delete_vms)

                  expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
                end
              end

              context 'when errand is run with when-changed' do
                before do
                  allow(JobRenderer).to receive_message_chain(:create, :render_job_instances).with([instance_plan])
                  allow(deployment_job).to receive(:needed_instance_plans).and_return([instance_plan])
                end

                let(:when_changed) { true }
                let(:instance_model) { Models::Instance.make }
                context 'when errand has been run before' do
                  let!(:errand_model) do
                    Models::ErrandRun.make(
                      successful: errand_success,
                      instance_id: instance_model.id,
                      successful_configuration_hash: successful_configuration_hash,
                      successful_packages_spec: JSON.dump(successful_packages_spec)
                    )
                  end

                  context 'when errand succeeded on the previous run' do
                    let(:errand_success) { true }

                    context 'when the errand configuration has NOT changed' do
                      let(:successful_configuration_hash) { 'last_successful_config' }
                      let(:successful_packages_spec) { {'packages' => 'last_successful_packages'} }

                      before do
                        allow(instance).to receive(:current_packages).and_return(successful_packages_spec)
                        allow(instance).to receive(:configuration_hash).and_return(successful_configuration_hash)
                      end
                      let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }

                      it 'does not run the errand and does not output ' do
                        expect(job_manager).to_not receive(:create_missing_vms)
                        expect(runner).to_not receive(:run)

                        subject.perform
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
                        expect(job_manager).to receive(:create_missing_vms)
                        expect(runner).to receive(:run)

                        expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
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
                        expect(job_manager).to receive(:create_missing_vms)
                        expect(runner).to receive(:run)

                        expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
                      end
                    end
                  end

                  context 'when errand failed on the previous run' do
                    let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }
                    let(:errand_success) { false }
                    let(:successful_configuration_hash) { '' }
                    let(:successful_packages_spec) { '' }


                    context 'when the errand configuration has NOT changed' do
                      before do
                        allow(instance).to receive(:current_packages).and_return({})
                        allow(instance).to receive(:configuration_hash).and_return('')
                      end

                      it 'runs the errand' do
                        expect(job_manager).to receive(:create_missing_vms)
                        expect(runner).to receive(:run)

                        expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
                      end
                    end

                    context 'when the errand configuration has changed' do
                      before do
                        allow(instance).to receive(:current_packages).and_return({'packages' => 'new_packages'})
                        allow(instance).to receive(:configuration_hash).and_return('new_config')
                      end

                      it 'runs the errands' do
                        expect(job_manager).to receive(:create_missing_vms)
                        expect(runner).to receive(:run)

                        expect(subject.perform).to eq("Errand 'fake-errand-name' completed successfully (exit code 0)")
                      end
                    end
                  end
                end

                context 'when errand has never been run before' do
                  let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: instance) }

                  it 'always runs the errand' do
                    allow(instance).to receive(:current_packages).and_return({'packages' => 'successful_packages_spec'})
                    allow(instance).to receive(:configuration_hash).and_return('successful_configuration_hash')

                    expect(job_manager).to receive(:create_missing_vms)
                    expect(runner).to receive(:run)

                    subject.perform
                  end
                end
              end
            end

            context 'when job representing an errand has 0 instances' do
              before { allow(deployment_job).to receive(:instances).with(no_args).and_return([]) }

              it 'raises an error because errand cannot be run on a job with 0 instances' do
                allow(subject).to receive(:with_deployment_lock).and_yield

                expect {
                  subject.perform
                }.to raise_error(InstanceNotFound, %r{fake-errand-name/0.*doesn't exist})
              end
            end
          end

          context "when job cannot run as an errand (e.g. marked as 'lifecycle: service')" do
            before { allow(deployment_job).to receive(:is_errand?).and_return(false) }

            it 'raises an error because non-errand jobs cannot be used with run errand cmd' do
              allow(subject).to receive(:with_deployment_lock).and_yield

              expect {
                subject.perform
              }.to raise_error(RunErrandError, /Instance group 'fake-errand-name' is not an errand/)
            end
          end
        end

        context 'when job representing an errand does not exist' do
          before { allow(planner).to receive(:instance_group).with('fake-errand-name').and_return(nil) }

          it 'raises an error because user asked to run an unknown errand' do
            allow(subject).to receive(:with_deployment_lock).and_yield

            expect {
              subject.perform
            }.to raise_error(JobNotFound, %r{fake-errand-name.*doesn't exist})
          end
        end
      end

      context 'when deployment does not exist' do
        it 'raises an error' do
          expect {
            subject.perform
          }.to raise_error(DeploymentNotFound, %r{fake-dep-name.*doesn't exist})
        end
      end
    end

    describe '#task_checkpoint' do
      subject { job.task_checkpoint }
      it_behaves_like 'raising an error when a task has timed out or been canceled'
    end
  end
end
