require 'spec_helper'

module Bosh::Director
  describe Jobs::RunErrand do
    subject(:job) { described_class.new('fake-dep-name', 'fake-errand-name', keep_alive) }
    let(:keep_alive) { false }

    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.manifest_with_errand
      manifest_hash['name'] = 'fake-dep-name'
      manifest_hash
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :run_errand }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      context 'when deployment exists' do
        let!(:deployment_model) do
          Models::Deployment.make(
            name: 'fake-dep-name',
            manifest: Psych.dump(manifest_hash),
            cloud_config: cloud_config
          )
        end

        before { allow(Config).to receive(:event_log).with(no_args).and_return(event_log) }
        let(:event_log) { Bosh::Director::EventLog::Log.new }

        before do
          allow(Config).to receive(:logger).with(no_args).and_return(logger)
          allow(Config).to receive(:cloud) { double('cloud') }
        end

        before do
          allow(DeploymentPlan::PlannerFactory).to receive(:new).
              and_return(planner_factory)
        end
        let(:planner_factory) do
          instance_double(
            'Bosh::Director::DeploymentPlan::PlannerFactory',
            planner: planner,
          )
        end
        let(:planner) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

        let(:cloud_config) { Models::CloudConfig.make }

        context 'when job representing an errand exists' do
          let(:deployment_job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-errand-name') }
          before { allow(planner).to receive(:job).with('fake-errand-name').and_return(deployment_job) }

          context 'when job can run as an errand (usually means lifecycle: errand)' do
            before { allow(deployment_job).to receive(:can_run_as_errand?).and_return(true) }

            context 'when job has at least 1 instance' do
              before { allow(deployment_job).to receive(:instances).with(no_args).and_return([instance]) }
              let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

              before { allow(Config).to receive(:result).with(no_args).and_return(result_file) }
              let(:result_file) { instance_double('Bosh::Director::TaskResultFile') }

              before { allow(Lock).to receive(:new).with('lock:deployment:fake-dep-name', timeout: 10).and_return(lock) }
              let(:lock) { instance_double('Bosh::Director::Lock') }

              before { allow(lock).to receive(:lock).and_yield }

              before { allow(deployment_job).to receive(:resource_pool).with(no_args).and_return(resource_pool) }
              let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool') }

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
                  with(event_log, be_a(Api::InstanceManager), log_bundles_cleaner, logger).
                  and_return(logs_fetcher)
              end
              let(:logs_fetcher) { instance_double('Bosh::Director::LogsFetcher') }

              before do
                allow(ResourcePoolUpdater).to receive(:new).
                  with(resource_pool).
                  and_return(rp_updater)
              end
              let(:rp_updater) { instance_double('Bosh::Director::ResourcePoolUpdater') }

              before do
                allow(DeploymentPlan::ResourcePools).to receive(:new).
                  with(event_log, [rp_updater]).
                  and_return(rp_manager)
              end
              let(:rp_manager) { instance_double('Bosh::Director::DeploymentPlan::ResourcePools', update: nil, refill: nil) }

              before do
                allow(Errand::JobManager).to receive(:new).
                  with(planner, deployment_job, blobstore, event_log, logger).
                  and_return(job_manager)
              end
              let(:job_manager) do
                instance_double('Bosh::Director::Errand::JobManager', {
                  prepare: nil,
                  update_instances: nil,
                  delete_instances: nil,
                })
              end

              before do
                allow(Errand::Runner).to receive(:new).
                  with(deployment_job, result_file, be_a(Api::InstanceManager), event_log, logs_fetcher).
                  and_return(runner)
              end
              let(:runner) { instance_double('Bosh::Director::Errand::Runner') }
              before do
                allow(runner).to receive(:run).
                  with(no_args).
                  and_return('fake-result-short-description')
              end

              it 'runs an errand with deployment lock and returns short result description' do
                called_after_block_check = double(:called_in_block_check, call: nil)
                expect(subject).to receive(:with_deployment_lock) do |deployment, &blk|
                  result = blk.call
                  called_after_block_check.call
                  result
                end

                expect(job_manager).to receive(:prepare).with(no_args).ordered

                expect(rp_manager).to receive(:update).with(no_args).ordered
                expect(job_manager).to receive(:update_instances).with(no_args).ordered

                expect(runner).to receive(:run).
                  with(no_args).
                  ordered.
                  and_return('fake-result-short-description')

                expect(job_manager).to receive(:delete_instances).with(no_args).ordered
                expect(rp_manager).to receive(:refill).with(no_args).ordered

                expect(called_after_block_check).to receive(:call).ordered

                expect(subject.perform).to eq('fake-result-short-description')
              end

              context 'when the errand fails to run' do
                let(:task) { instance_double('Bosh::Director::Models::Task') }
                let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }

                it 'cleans up the instances anyway' do
                  error = Exception.new
                  expect(runner).to receive(:run).with(no_args).and_raise(error)
                  expect(job_manager).to receive(:delete_instances).with(no_args).ordered
                  expect(rp_manager).to receive(:refill).with(no_args).ordered

                  expect { subject.perform }.to raise_error(error)
                end
              end

              context 'when the errand is canceled' do
                before { allow(Api::TaskManager).to receive(:new).and_return(task_manager) }
                let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }

                before { allow(task).to receive(:state).and_return('cancelling') }
                let(:task) { instance_double('Bosh::Director::Models::Task') }

                before { job.task_id = 'some-task' }

                context 'when agent is able to cancel run_errand task successfully' do
                  it 'cancels the errand, raises TaskCancelled, and cleans up errand VMs' do
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered
                    expect(job_manager).to receive(:delete_instances).with(no_args).ordered
                    expect(rp_manager).to receive(:refill).with(no_args).ordered

                    expect { subject.perform }.to raise_error(TaskCancelled)
                  end

                  it 'does not allow cancellation while cleaning up errand VMs' do
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered
                    expect(job_manager).to(receive(:delete_instances).with(no_args).ordered) { job.task_checkpoint }
                    expect(rp_manager).to receive(:refill).with(no_args).ordered

                    expect { subject.perform }.to raise_error(TaskCancelled)
                  end
                end

                context 'when the agent throws an exception while cancelling run_errand task' do
                  it 'raises RpcRemoteException and cleans up errand VMs' do
                    error = RpcRemoteException.new
                    expect(job_manager).to receive(:update_instances).with(no_args).ordered
                    expect(runner).to receive(:run).with(no_args).ordered.and_yield
                    expect(runner).to receive(:cancel).with(no_args).ordered.and_raise(error)
                    expect(job_manager).to receive(:delete_instances).with(no_args).ordered
                    expect(rp_manager).to receive(:refill).with(no_args).ordered

                    expect { subject.perform }.to raise_error(error)
                  end
                end
              end

              context 'when errand is run with keep-alive' do
                let(:keep_alive) { true }

                it 'does not delete instances' do
                  expect(job_manager).to_not receive(:delete_instances)

                  expect(subject.perform).to eq('fake-result-short-description')
                end

                it 'does not refill resource pool' do
                  expect(rp_manager).to_not receive(:refill)

                  expect(subject.perform).to eq('fake-result-short-description')
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
            before { allow(deployment_job).to receive(:can_run_as_errand?).and_return(false) }

            it 'raises an error because non-errand jobs cannot be used with run errand cmd' do
              allow(subject).to receive(:with_deployment_lock).and_yield

              expect {
                subject.perform
              }.to raise_error(RunErrandError, /Job `fake-errand-name' is not an errand/)
            end
          end
        end

        context 'when job representing an errand does not exist' do
          before { allow(planner).to receive(:job).with('fake-errand-name').and_return(nil) }

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
