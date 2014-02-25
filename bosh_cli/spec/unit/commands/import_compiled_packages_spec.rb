require 'fakefs/spec_helpers'
require 'spec_helper'

describe Bosh::Cli::Command::ImportCompiledPackages do
  subject(:command) { described_class.new }

  describe 'import compiled_packages' do
    with_director

    context 'when director is targeted' do
      with_target

      context 'when the user is logged in' do
        with_logged_in_user

        context 'when the tarball of compiled packages does not exist' do
          it 'fails with an error' do
            expect {
              subject.perform('/does/not/exist.tgz')
            }.to raise_error(Bosh::Cli::CliError, 'Archive does not exist')
          end
        end

        context 'when the archive of compiled packages exists' do
          include FakeFS::SpecHelpers
          before { FileUtils.touch('/some-real-archive.tgz') }

          before { allow(Bosh::Cli::Client::CompiledPackagesClient).to receive(:new).with(director).and_return(client) }
          let(:client) { instance_double('Bosh::Cli::Client::CompiledPackagesClient') }

          it 'makes the proper request' do
            expect(client).to receive(:import).with('/some-real-archive.tgz')
            command.perform('/some-real-archive.tgz')
          end

          context 'when the task errs' do
            let(:some_task_id) { '1' }

            context 'when the task status is :error' do
              before { client.stub(:import).and_return([:error, some_task_id]) }

              it 'changes the exit status to 1' do
                expect {
                  command.perform('/some-real-archive.tgz')
                }.to change { command.exit_code }.from(0).to(1)
              end
            end

            context 'when the task status is :failed' do
              before { client.stub(:import).and_return([:failed, some_task_id]) }

              it 'changes the exit status to 1' do
                expect {
                  command.perform('/some-real-archive.tgz')
                }.to change { command.exit_code }.from(0).to(1)
              end
            end
          end

          context 'when the task is done' do
            let(:some_task_id) { '1' }

            context 'when the task status is :done' do
              it 'returns exit status 0' do
                client.stub(:import).and_return([:done, some_task_id])

                command.perform('/some-real-archive.tgz')
                expect(command.exit_code).to eq(0)
              end
            end
          end
        end
      end

      it_requires_logged_in_user ->(command) { command.perform(nil) }
    end

    it_requires_target ->(command) { command.perform(nil) }
  end
end
