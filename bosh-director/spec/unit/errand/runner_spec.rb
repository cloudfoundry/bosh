require 'spec_helper'

module Bosh::Director
  describe Errand::Runner do
    subject { described_class.new(job, result_file, instance_manager, event_log, logs_fetcher) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job-name') }
    let(:result_file) { instance_double('Bosh::Director::TaskResultFile') }
    let(:instance_manager) { Bosh::Director::Api::InstanceManager.new }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
    let(:logs_fetcher) { instance_double('Bosh::Director::LogsFetcher') }

    context 'when there is at least 1 instance' do
      before { allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance', index: 0) }

      # This instance will not currently run an errand
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance', index: 1) }

      before { allow(instance1).to receive(:model).with(no_args).and_return(instance1_model) }
      let(:instance1_model) do
        Models::Instance.make(
          job: 'fake-job-name',
          index: 0,
          vm: vm,
          deployment: deployment,
        )
      end

      let(:deployment) { Models::Deployment.make(name: 'fake-dep-name') }
      let(:vm) { Models::Vm.make(deployment: deployment) }

      before { allow(AgentClient).to receive(:with_defaults).with(vm.agent_id).and_return(agent_client) }
      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

      describe '#run' do
        before { allow(event_log).to receive(:begin_stage).and_return(event_log_stage) }
        let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

        before { allow(event_log_stage).to receive(:advance_and_track).and_yield }

        context 'when agent is able to run errands' do
          before { allow(Config).to receive(:result).and_return(result_file) }
          let(:result_file) { instance_double('File', write: nil) }

          let(:agent_task_result) do
            {
              'exit_code' => 123,
              'stdout' => 'fake-stdout',
              'stderr' => 'fake-stderr',
            }
          end

          before do
            allow(agent_client).to receive(:run_errand).
              and_return('agent_task_id' => 'fake-agent-task-id')

            allow(logs_fetcher).to receive(:fetch).
              and_return('fake-logs-blobstore-id')

            allow(agent_client).to receive(:wait_for_task).and_return(agent_task_result)
          end

          it 'runs a block argument to run function while polling for errand to finish' do
            fake_block = Proc.new {}

            expect(agent_client).to receive(:run_errand).with(no_args)

            expect(agent_client).to receive(:wait_for_task) do |args, &blk|
              expect(args).to eq('fake-agent-task-id')
              expect(blk).to eq(fake_block)
              agent_task_result
            end

            subject.run(&fake_block)
          end

          it 'writes run_errand response with exit_code, stdout, stderr and logs result to task result file' do
            expect(result_file).to receive(:write) do |text|
              expect(JSON.parse(text)).to eq(
                'exit_code' => 123,
                'stdout' => 'fake-stdout',
                'stderr' => 'fake-stderr',
                'logs' => {
                  'blobstore_id' => 'fake-logs-blobstore-id',
                },
              )
            end
            subject.run
          end

          it 'records errand running in the event log' do
            event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
            expect(event_log).to receive(:begin_stage).with('Running errand', 1).and_return(event_log_stage)
            expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/0').and_yield
            subject.run
          end

          it 'returns a short description from errand result' do
            errand_result = instance_double('Bosh::Director::Errand::Result', to_hash: {})

            expect(errand_result).to receive(:short_description).
               with('fake-job-name').
               and_return('fake-short-description')

            expect(Errand::Result).to receive(:from_agent_task_results).
              with(agent_task_result, 'fake-logs-blobstore-id').
              and_return(errand_result)

            expect(subject.run).to eq('fake-short-description')
          end

          it 'fetches the logs from agent with correct job type and filters' do
            expect(logs_fetcher).to receive(:fetch).with(instance1.model, 'job', nil)
            subject.run
          end

          it 'writes run_errand response with nil fetched lobs blobstore id if fetching logs fails' do
            expect(result_file).to receive(:write) do |text|
              expect(JSON.parse(text)).to eq(
                'exit_code' => 123,
                'stdout' => 'fake-stdout',
                'stderr' => 'fake-stderr',
                'logs' => {
                  'blobstore_id' => nil,
                },
              )
            end

            error = DirectorError.new
            expect(logs_fetcher).to receive(:fetch).and_raise(error)

            expect { subject.run }.to raise_error(error)
          end

          context 'when errand is canceled' do
            before do
              allow(agent_client).to receive(:wait_for_task) do |args, &blk|
                # Errand is cancelled by the user
                raise TaskCancelled if blk

                # Agent returns result after cancelling errand
                agent_task_result
              end
            end

            it 're-raises task cancelled exception is task is considered to be cancelled' do
              expect { subject.run {} }.to raise_error(TaskCancelled)
            end

            it 'writes the errand result received from the agent\'s cancellation' do
              expect(result_file).to receive(:write) do |text|
                expect(JSON.parse(text)).to eq(
                  'exit_code' => 123,
                  'stdout' => 'fake-stdout',
                  'stderr' => 'fake-stderr',
                  'logs' => {
                    'blobstore_id' => 'fake-logs-blobstore-id'
                  },
                )
              end
              expect { subject.run {} }.to raise_error
            end

            it 'raises cancel error even if fetching logs fails' do
              expect(logs_fetcher).to receive(:fetch).and_raise(DirectorError)
              expect { subject.run {} }.to raise_error(TaskCancelled)
            end

            it 'writes run_errand response with nil blobstore_id if fetching logs fails' do
              expect(result_file).to receive(:write) do |text|
                expect(JSON.parse(text)).to eq(
                  'exit_code' => 123,
                  'stdout' => 'fake-stdout',
                  'stderr' => 'fake-stderr',
                  'logs' => {
                    'blobstore_id' => nil,
                  },
                )
              end

              expect(logs_fetcher).to receive(:fetch).and_raise(DirectorError)
              expect { subject.run {} }.to raise_error
            end
          end
        end

        context 'when agent does not support run_errand command' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"run_errand", "error"=>"details"}') }

          it 'raises an error' do
            expect { subject.run }.to raise_error(error)
          end

          it 'does write run_errand agent response to result file because we did not run errand' do
            expect(result_file).to_not receive(:write)
            expect { subject.run }.to raise_error
          end

          it 'does not try to fetch logs from the agent because we did not run errand' do
            expect(logs_fetcher).to_not receive(:fetch)
            expect { subject.run }.to raise_error
          end
        end

        context 'when agent times out responding to start errand task status check' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('timeout') }

          it 'raises original timeout error' do
            expect { subject.run }.to raise_error(error)
          end

          it 'does write run_errand agent response to result file because there is was no response' do
            expect(result_file).to_not receive(:write)
            expect { subject.run }.to raise_error
          end

          it 'does not try to fetch logs from the agent because we failed contacting it already' do
            expect(logs_fetcher).to_not receive(:fetch)
            expect { subject.run }.to raise_error
          end
        end

        context 'when job instance is not associated with any VM yet' do
          before { instance1_model.update(vm: nil) }

          it 'raises an error' do
            expect { subject.run }.to raise_error(InstanceVmMissing, %r{fake-job-name/0.*doesn't reference a VM})
          end
        end
      end

      describe '#cancel' do
        context 'when an errand is running' do
          before { allow(subject).to receive(:agent_task_id).and_return('fake-agent-task-id') }

          it 'sends cancel_task message to the agent' do
            expect(agent_client).to receive(:cancel_task).with('fake-agent-task-id')
            subject.cancel
          end
        end

        context 'when no errand is running' do
          it 'does not send a message to the agent' do
            expect(agent_client).not_to receive(:cancel_task)
            subject.cancel
          end
        end
      end
    end

    context 'when there are 0 instances' do
      before { allow(job).to receive(:instances).with(no_args).and_return([]) }

      describe '#run' do
        it 'raises an error' do
          expect { subject.run }.to raise_error(
            DirectorError,
            /Must have at least one job instance to run an errand/,
          )
        end
      end

      describe '#cancel' do
        it 'does not send a message to the agent' do
          expect { subject.cancel }.not_to raise_error
        end
      end
    end
  end
end
