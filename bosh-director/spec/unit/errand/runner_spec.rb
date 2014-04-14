require 'spec_helper'

module Bosh::Director
  describe Errand::Runner do
    subject { described_class.new(job, result_file, instance_manager, event_log) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job-name') }
    let(:result_file) { instance_double('Bosh::Director::TaskResultFile') }
    let(:instance_manager) { Bosh::Director::Api::InstanceManager.new }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

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

          let(:start_response) { { 'agent_task_id' => 'fake-agent-task-id' } }
          let(:errand_result) {
            {
              'exit_code' => 123,
              'stdout' => 'fake-stdout',
              'stderr' => 'fake-stderr',
            }
          }

          before do
            allow(agent_client).to receive(:start_errand).and_return(start_response)
            allow(agent_client).to receive(:wait_for_task).and_return(errand_result)
          end

          it 'runs a block while polling' do
            fake_block = Proc.new {}

            expect(agent_client).to receive(:start_errand).with(no_args)

            expect(agent_client).to receive(:wait_for_task) do |args, &blk|
              expect(args).to eq('fake-agent-task-id')
              expect(blk).to eq(fake_block)
              errand_result
            end

            subject.run(&fake_block)
          end

          it 'writes run_errand agent response with exit_code, stdout and stderr to task result file' do
            result_file.should_receive(:write) do |text|
              expect(JSON.parse(text)).to eq(errand_result)
            end

            subject.run
          end

          it 'records errand running in the event log' do
            event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
            expect(event_log).to receive(:begin_stage).with('Running errand', 1).and_return(event_log_stage)

            expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/0').and_yield

            subject.run
          end

          %w(exit_code stdout stderr).each do |field_name|
            it "raises an error when #{field_name} is missing in the errand result" do
              invalid_errand_result = errand_result.reject { |k, _| k == field_name }
              allow(agent_client).to receive(:wait_for_task).and_return(invalid_errand_result)

              expect { subject.run }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
            end
          end

          it 'does not pass through unexpected fields in the errand result' do
            errand_result_with_extras = errand_result.dup
            errand_result_with_extras['unexpected-key'] = 'extra-value'
            allow(agent_client).to receive(:wait_for_task).and_return(errand_result_with_extras)

            result_file.should_receive(:write) do |text|
              expect(JSON.parse(text)).to eq(errand_result)
            end

            subject.run
          end

          context 'when errand exit_code is 0' do
            before do
              allow(agent_client).to receive(:wait_for_task).and_return(errand_result.merge('exit_code' => 0))
            end

            it 'returns successful errand completion message as task short result (not result file)' do
              expect(subject.run).to eq('Errand `fake-job-name\' completed successfully (exit code 0)')
            end
          end

          context 'when errand exit_code is non-0' do
            before do
              allow(agent_client).to receive(:wait_for_task).and_return(errand_result.merge('exit_code' => 123))
            end

            it 'returns error errand completion message as task short result (not result file)' do
              expect(subject.run).to eq('Errand `fake-job-name\' completed with error (exit code 123)')
            end
          end

          context 'when errand is canceled' do
            before do
              allow(agent_client).to receive(:wait_for_task) do |args, &blk|
                raise TaskCancelled if blk
                errand_result
              end
            end

            it 'writes the errand result' do
              result_file.should_receive(:write) do |text|
                expect(JSON.parse(text)).to eq(errand_result)
              end

              expect { subject.run {} }.to raise_error(TaskCancelled)
            end
          end
        end

        context 'when agent does not support run_errand command' do
          before { allow(agent_client).to receive(:start_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"run_errand", "error"=>"details"}') }

          it 'raises an error' do
            expect { subject.run }.to raise_error(error)
          end
        end

        context 'when agent times out responding to start errand task status check' do
          before { allow(agent_client).to receive(:start_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('timeout') }

          it 'propagates timeout error' do
            expect { subject.run }.to raise_error(error)
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
