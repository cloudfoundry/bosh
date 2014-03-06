require 'spec_helper'

module Bosh::Director
  describe Jobs::RunErrand do
    subject(:job) { described_class.new(deployment.name, instance.job) }
    let(:deployment) { Models::Deployment.make(name: 'fake-dep-name') }
    let(:vm) { Models::Vm.make(deployment: deployment) }

    let(:instance) do
      Models::Instance.make(
        job: 'fake-errand-name',
        index: 0,
        vm: vm,
        deployment: deployment,
      )
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :run_errand }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      context 'when deployment and job representing an errand exists' do
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

            job.perform
          end

          %w(exit_code stdout stderr).each do |field_name|
            it "raises an error when #{field_name} is missing in the errand result" do
              invalid_errand_result = errand_result.reject { |k, _| k == field_name }
              allow(agent_client).to receive(:run_errand).and_return(invalid_errand_result)

              expect { job.perform }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
            end
          end

          it 'does not pass through unexpected fields in the errand result' do
            errand_result_with_extras = errand_result.dup
            errand_result_with_extras['unexpected-key'] = 'extra-value'
            allow(agent_client).to receive(:run_errand).and_return(errand_result_with_extras)

            result_file.should_receive(:write) do |text|
              expect(JSON.parse(text)).to eq(errand_result)
            end

            job.perform
          end

          context 'when errand exit_code is 0' do
            before { allow(agent_client).to receive(:run_errand).and_return(errand_result.merge('exit_code' => 0)) }

            it 'returns successful errand completion message as task short result (not result file)' do
              expect(job.perform).to eq('Errand `fake-errand-name\' completed successfully (exit code 0)')
            end
          end

          context 'when errand exit_code is non-0' do
            before { allow(agent_client).to receive(:run_errand).and_return(errand_result.merge('exit_code' => 123)) }

            it 'returns error errand completion message as task short result (not result file)' do
              expect(job.perform).to eq('Errand `fake-errand-name\' completed with error (exit code 123)')
            end
          end
        end

        context 'when agent does not support run_errand command' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"run_errand", "error"=>"details"}') }

          it 'raises an error' do
            expect { job.perform }.to raise_error(error)
          end
        end

        context 'when agent times out responding to run errand task status check' do
          before { allow(agent_client).to receive(:run_errand).and_raise(error) }
          let(:error) { RpcRemoteException.new('timeout') }

          it 'propagates timeout error' do
            expect { job.perform }.to raise_error(error)
          end
        end

        context 'when job instance is not associated with any VM yet' do
          before { instance.update(vm: nil) }

          it 'raises an error' do
            expect {
              job.perform
            }.to raise_error(InstanceVmMissing, %r{fake-errand-name/0.*doesn't reference a VM})
          end
        end
      end

      context 'when deployment does not exist' do
        before { allow(deployment).to receive(:name).and_return('unknown-dep-name') }

        it 'raises an error' do
          expect {
            job.perform
          }.to raise_error(DeploymentNotFound, %r{unknown-dep-name.*doesn't exist})
        end
      end

      context 'when job representing an errand does not exist' do
        before { allow(instance).to receive(:job).and_return('unknown-job-name') }

        it 'raises an error because user asked to run an unknown errand' do
          expect {
            job.perform
          }.to raise_error(InstanceNotFound, %r{fake-dep-name/unknown-job-name/0.*doesn't exist})
        end
      end

      context 'when job representing an errand has 0 instances' do
        # since DB does not record jobs with 0 instances
        # it's not different from an unknown errand
      end
    end
  end
end
