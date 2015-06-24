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
          let(:some_task_id) { '1' }
          before {
            allow(Bosh::Cli::Client::ExportReleaseClient).to receive(:new).with(director).and_return(client)
            allow(director).to receive(:list_releases)
          }

          context 'when user did not choose deployment' do
            before { allow(command).to receive(:deployment).and_return(nil) }

            it 'raises an error with choose deployment message' do
              expect {
                command.export('release/1','centos-7/0000')
              }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
            end
          end

          context 'when a deployment is targeted' do
            before do
              allow(command).to receive(:deployment).and_return(spec_asset('manifests/manifest_for_export_release.yml'))
              allow(director).to receive(:uuid).and_return('123456-789abcdef')
            end

            context 'when export release command args are not following required format (string with slash in the middle)' do
              before {
                allow(client).to receive(:export).with('export_support', 'release', '1', 'centos-7', '0000')
                allow(command).to receive(:release_exists?).and_return(true)
              }

              it 'should raise an ArgumentError exception' do
                expect {command.export('release 1', 'centos-7 0000')}.to raise_error(ArgumentError, '"release 1" must be in the form name/version')
              end
            end

            context 'when export release command is executed' do
              before { allow(command).to receive(:release_exists?).and_return(true) }
              it 'makes the proper request' do
                expect(client).to receive(:export).with('export_support', 'release', '1', 'centos-7', '0000')
                command.export('release/1', 'centos-7/0000')
              end
            end

            context 'when the task status is :failed' do
              before {
                allow(client).to receive(:export).and_return([:failed, some_task_id])
                allow(command).to receive(:release_exists?).and_return(true)
              }

              it 'changes the exit status to 1' do
                expect {
                  command.export('release/1', 'centos-7/0000')
                }.to change { command.exit_code }.from(0).to(1)
              end
            end

            context 'when the task is done' do
              context 'when the task status is :done' do
                before { allow(command).to receive(:release_exists?).and_return(true) }

                it 'returns exit status 0' do
                  allow(client).to receive(:export).and_return([:done, some_task_id])

                  command.export('release/1', 'centos-7/0000')
                  expect(command.exit_code).to eq(0)
                end
              end
            end

            context 'when checking if the release exists' do
              before{
                allow(command).to receive(:prepare_deployment_manifest).and_return('export_support')
              }

              it 'does not finds the release if it does not exists in director' do
                allow(client).to receive(:export).with('export_support', 'test', '1', 'centos-7', '0000')
                allow(director).to receive(:list_releases).and_return([{"name"=>"bosh","release_versions"=>[{"version" => "2145"}]}])

                expect(command.release_exists?('test','1')).to eq(false)
              end

              it 'finds the release if exists in director' do
                allow(client).to receive(:export).with('export_support', 'bosh', '2145', 'centos-7', '0000')
                allow(director).to receive(:list_releases).and_return([{"name"=>"bosh","release_versions"=>[{"version" => "2145"}]}])

                expect(command.release_exists?('bosh','2145')).to eq(true)
              end

              it 'returns an error if release not found' do
                allow(client).to receive(:export).with('export_support', 'test', '1', 'centos-7', '0000')
                allow(director).to receive(:list_releases).and_return([{"name"=>"bosh","release_versions"=>[{"version" => "2145"}]}])

                expect {
                  command.export('test/1','centos-7/0000')
                }.to raise_error(Bosh::Cli::CliError, /does not exist/)
              end

              it 'does not return an error if release is found' do
                allow(client).to receive(:export)
                allow(director).to receive(:list_releases).and_return([{"name"=>"bosh","release_versions"=>[{"version" => "2145"}]}])

                expect {
                  command.export('bosh/2145','centos-7/0000')
                }.not_to raise_error
              end
            end
          end
        end
      end
    end
  end
end
