require 'spec_helper'

module Bosh::Cli::Command::Release
  describe ExportRelease do
    subject(:command) { described_class.new }

    describe 'export release' do
      with_director

      context 'when director is targeted' do
        with_target

        context 'when the user is logged in' do
          with_logged_in_user
          let(:client) { instance_double('Bosh::Cli::Client::ExportReleaseClient') }
          before { allow(Bosh::Cli::Client::ExportReleaseClient).to receive(:new).with(director).and_return(client) }
          let(:some_task_id) { '1' }

          context 'when export release command is executed' do
            it 'makes the proper request' do
              expect(client).to receive(:export).with('release','1','centos-7','0000')
              command.export('release/1','centos-7/0000')
            end
          end

          context 'when the task status is :failed' do
            before { allow(client).to receive(:export).and_return([:failed, some_task_id]) }

            it 'changes the exit status to 1' do
              expect {
                command.export('release/1','centos-7/0000')
              }.to change { command.exit_code }.from(0).to(1)
            end
          end

          context 'when the task is done' do
            context 'when the task status is :done' do
              it 'returns exit status 0' do
                allow(client).to receive(:export).and_return([:done, some_task_id])

                command.export('release/1','centos-7/0000')
                expect(command.exit_code).to eq(0)
              end
            end
          end
        end
      end
    end
  end
end
