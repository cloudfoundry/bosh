require 'spec_helper'

module Bosh::Director
  describe Errand::Runner do
    subject { described_class.new(job, result_file, instance_manager, event_log) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job-name') }
    let(:result_file) { instance_double('Bosh::Director::TaskResultFile') }
    let(:instance_manager) { Bosh::Director::Api::InstanceManager.new }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

    describe '#run' do
      context 'when there is at least 1 instance' do
        before { allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
        let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

        # This instance will not currently run an errand
        let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

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

        context 'when agent is able to run errands' do
          errand_result = {
            'exit_code' => 123,
            'stdout' => 'fake-stdout',
            'stderr' => 'fake-stderr',
          }

          before { allow(Config).to receive(:result).and_return(result_file) }
          let(:result_file) { instance_double('File', write: nil) }

          it 'writes run_errand agent response with exit_code, stdout and stderr to task result file' do
            allow(agent_client).to receive(:run_errand).and_return(errand_result)

            result_file.should_receive(:write) do |text|
              expect(JSON.parse(text)).to eq(errand_result)
            end

            subject.run
          end

          %w(exit_code stdout stderr).each do |field_name|
            it "raises an error when #{field_name} is missing in the errand result" do
              invalid_errand_result = errand_result.reject { |k, _| k == field_name }
              allow(agent_client).to receive(:run_errand).and_return(invalid_errand_result)

              expect { subject.run }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
            end
          end

          it 'does not pass through unexpected fields in the errand result' do
            errand_result_with_extras = errand_result.dup
            errand_result_with_extras['unexpected-key'] = 'extra-value'
            allow(agent_client).to receive(:run_errand).and_return(errand_result_with_extras)

            result_file.should_receive(:write) do |text|
              expect(JSON.parse(text)).to eq(errand_result)
            end

            subject.run
          end

          context 'when errand exit_code is 0' do
            before { allow(agent_client).to receive(:run_errand).and_return(errand_result.merge('exit_code' => 0)) }

            it 'returns successful errand completion message as task short result (not result file)' do
              expect(subject.run).to eq('Errand `fake-job-name\' completed successfully (exit code 0)')
            end
          end

          context 'when errand exit_code is non-0' do
            before { allow(agent_client).to receive(:run_errand).and_return(errand_result.merge('exit_code' => 123)) }

            it 'returns error errand completion message as task short result (not result file)' do
              expect(subject.run).to eq('Errand `fake-job-name\' completed with error (exit code 123)')
            end
          end
        end

        context 'when agent does not support run_errand command' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"run_errand", "error"=>"details"}') }

          it 'raises an error' do
            expect { subject.run }.to raise_error(error)
          end
        end

        context 'when agent times out responding to run errand task status check' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('timeout') }

          it 'propagates timeout error' do
            expect { subject.run }.to raise_error(error)
          end
        end

        context 'when job instance is not associated with any VM yet' do
          before { instance1_model.update(vm: nil) }

          it 'raises an error' do
            expect {
              subject.run
            }.to raise_error(InstanceVmMissing, %r{fake-job-name/0.*doesn't reference a VM})
          end
        end
      end
    end

    context 'when there are 0 instances' do
      before { allow(job).to receive(:instances).with(no_args).and_return([]) }

      it 'raises an error' do
        expect {
          subject.run
        }.to raise_error(
          DirectorError,
          /Must have at least one job instance to run an errand/,
        )
      end
    end
  end
end
