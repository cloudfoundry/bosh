require 'spec_helper'

module Bosh::Cli
  describe Command::Vm do
    let(:command) { Command::Vm.new }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }
    let(:deployment) { 'dep1' }
    let(:target) { 'http://example.org' }
    let(:deployment_manifest) { { 'name' => deployment } }

    before do
      allow(command).to receive(:director).and_return(director)
      allow(command).to receive(:nl)
      command.options[:target] = target
      allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, hash: deployment_manifest, name: 'dep1'))
      allow(command).to receive(:show_current_state)
    end

    describe 'usage' do
      it 'lists arguments' do
        expect(Config.commands['vm resurrection'].usage_with_params).to eq('vm resurrection [<job>] [<index>] <new_state>')
      end
    end

    it 'requires login' do
        allow(command).to receive(:logged_in?) { false }
        expect {
          command.resurrection_state('on')
        }.to raise_error(Bosh::Cli::CliError, "Please log in first")
    end

    context 'when logged in' do
      before { allow(command).to receive(:logged_in?) { true } }

      context 'when "job & index" are not specified' do
        it 'changes the state of all jobs' do
          expect(director).to receive(:change_vm_resurrection_for_all).with(false)
          command.resurrection_state('on')
        end
      end

      context 'when "job & index" are specified' do
        context 'and there are no jobs of the specified type in the deployment' do
          let(:deployment_manifest) do
            {
              'name' => deployment,
              'jobs' => []
            }
          end

          it 'errors' do
            expect {
              command.resurrection_state('job1', '0', 'on')
            }.to raise_error(CliError, "Job `job1' doesn't exist")
          end
        end

        context 'and there is only one job of the specified type in the deployment' do
          let(:deployment_manifest) do
            {
              'name' => deployment,
              'jobs' => [
                {
                  'name'      => 'job1',
                  'instances' => 1
                }
              ]
            }
          end

          it 'allows the user to omit the index' do
            expect(director).to receive(:change_vm_resurrection).with(deployment, 'job1', 0, false)
            command.resurrection_state('job1', 'on')
          end
        end

        context 'and there are many jobs of the specified type in the deployment' do
          let(:deployment_manifest) do
            {
              'name' => deployment,
              'jobs' => [
                {
                  'name'      => 'dea',
                  'instances' => 50
                }
              ]
            }
          end

          it 'does not allow the user to omit the index' do
            expect {
              command.resurrection_state('dea', 'on')
            }.to raise_error(CliError, 'You should specify the job index. There is more than one instance of this job type.')
          end

          describe 'changing the state' do
            it 'should toggle the resurrection state to true' do
              expect(director).to receive(:change_vm_resurrection).with(deployment, 'dea', 1, false).exactly(4).times
              command.resurrection_state('dea', '1', 'on')
              command.resurrection_state('dea/1', 'enable')
              command.resurrection_state('dea', '1', 'yes')
              command.resurrection_state('dea/1', 'true')
            end

            it 'should toggle the resurrection state to false' do
              expect(director).to receive(:change_vm_resurrection).with(deployment, 'dea', 3, true).exactly(4).times
              command.resurrection_state('dea', '3', 'disable')
              command.resurrection_state('dea/3', 'off')
              command.resurrection_state('dea', '3', 'no')
              command.resurrection_state('dea/3', 'false')
            end

            it 'should error with an incorrect value' do
              expect { command.resurrection_state('dea', '1', 'nada') }.to raise_error CliError
            end
          end
        end
      end
    end

  end
end
