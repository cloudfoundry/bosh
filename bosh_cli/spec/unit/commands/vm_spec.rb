require 'spec_helper'

module Bosh::Cli
  describe Command::Vm do
    let(:command) { Command::Vm.new }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }
    let(:deployment) { 'dep1' }
    let(:target) { 'http://example.org' }

    before do
      allow(command).to receive(:director).and_return(director)
      command.options[:target] = target
    end

    describe 'resurrection' do
      let(:deployment_manifest) do
        {
            'name' => deployment,
            'jobs' => [
                {
                    'name' => 'dea',
                    'instances' => 50
                }
            ]
        }
      end

      before do
        allow(command).to receive(:nl)
        allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, hash: deployment_manifest, name: 'dep1'))
        allow(command).to receive(:show_current_state)
      end

      describe 'usage' do
        it 'lists arguments' do
          expect(Config.commands['vm resurrection'].usage_with_params).to eq('vm resurrection [<job>] [<index_or_id>] <new_state>')
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

        context 'when "job & index_or_id" are not specified' do
          it 'changes the state of all jobs' do
            expect(director).to receive(:change_vm_resurrection_for_all).with(false)
            command.resurrection_state('on')
          end
        end

        context 'when "job & index_or_id" are specified' do
          context 'and there is only one job of the specified type in the deployment' do
            let(:deployment_manifest) do
              {
                  'name' => deployment,
                  'jobs' => [
                      {
                          'name' => 'job1',
                          'instances' => 1
                      }
                  ]
              }
            end

            it 'allows the user to omit the index_or_id (though the director will complain)' do
              expect(director).to receive(:change_vm_resurrection).with(deployment, 'job1', nil, false)
              command.resurrection_state('job1', 'on')
            end
          end

          describe 'changing the state' do
            it 'should toggle the resurrection state to true' do
              expect(director).to receive(:change_vm_resurrection).with(deployment, 'dea', '1', false).exactly(4).times
              command.resurrection_state('dea', '1', 'on')
              command.resurrection_state('dea/1', 'enable')
              command.resurrection_state('dea', '1', 'yes')
              command.resurrection_state('dea/1', 'true')
            end

            it 'should toggle the resurrection state to false' do
              expect(director).to receive(:change_vm_resurrection).with(deployment, 'dea', '3', true).exactly(4).times
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

    describe 'deleting a vm' do
      it 'requires login' do
        allow(command).to receive(:logged_in?) { false }
        expect {
          command.delete('vm_cid')
        }.to raise_error(Bosh::Cli::CliError, "Please log in first")
      end

      context 'when the user is logged in' do
        before { allow(command).to receive(:logged_in?) { true } }

        context 'when interactive' do
          before do
            command.options[:non_interactive] = false
          end

          context 'when the user confirms the vm deletion' do
            it 'deletes the vm' do
              expect(command).to receive(:confirmed?).with("Are you sure you want to delete vm 'vm_cid'?").and_return(true)
              expect(director).to receive(:delete_vm_by_cid).with('vm_cid')
              command.delete('vm_cid')
            end
          end

          context 'when the user does not confirms the vm deletion' do
            it 'does not delete the vm' do
              expect(command).to receive(:confirmed?).with("Are you sure you want to delete vm 'vm_cid'?").and_return(false)
              expect(director).not_to receive(:delete_vm_by_cid)
              command.delete('vm_cid')
            end
          end
        end

        context 'when non interactive' do
          before do
            command.options[:non_interactive] = true
          end

          it 'deletes the vm' do
            expect(director).to receive(:delete_vm_by_cid).with('vm_cid')
            command.delete('vm_cid')
          end
        end
      end
    end
  end
end
