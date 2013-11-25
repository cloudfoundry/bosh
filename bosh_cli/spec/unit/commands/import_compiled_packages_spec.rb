require 'fakefs/spec_helpers'
require 'spec_helper'

describe Bosh::Cli::Command::ImportCompiledPackages do
  subject(:command) { described_class.new }

  context 'when cli is targeted' do
    before { command.stub(target: 'faketarget.com') }

    context 'when the user is logged in' do
      before { command.stub(logged_in?: true) }
      context 'when the tarball of compiled packages does not exist' do
        it 'fails with an error' do
          expect {
            subject.perform('/does/not/exist.tgz')
          }.to raise_error(Bosh::Cli::CliError, 'Archive does not exist')
        end
      end

      context 'when the archive of compiled packages exists' do
        let(:director) { double('cli director') }
        before { command.stub(director: director) }
        include FakeFS::SpecHelpers
        before { FileUtils.touch('/some-real-archive.tgz') }

        it 'makes the proper request' do
          client = double('compiled package client', import: nil)
          Bosh::Cli::Client::CompiledPackagesClient.stub(:new).with(director).and_return(client)
          command.perform('/some-real-archive.tgz')

          expect(client).to have_received(:import).with('/some-real-archive.tgz')
        end

        context 'when the task errs' do
          let(:some_task_id) { '1' }
          let(:client) { double('compiled package client') }
          before { Bosh::Cli::Client::CompiledPackagesClient.stub(new: client) }

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
          let(:client) { double('compiled package client') }
          before { Bosh::Cli::Client::CompiledPackagesClient.stub(new: client) }

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

    context 'when the user is not logged in' do
      before { command.stub(logged_in?: false) }

      it 'fails and tells the user to login' do
        expect { command.perform('fake/exported_packages') }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end
  end

  context 'when nothing is targeted' do
    before { command.stub(target: nil) }
    it 'fails with required target error' do
      expect { command.perform('fake/exported_packages') }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
    end
  end
end
