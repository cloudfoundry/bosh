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
            allow(director).to receive(:get_task_result_log).and_return("{\"blobstore_id\":\"57e2a69d-1f06-4f72-9560-f8f9b38cbbb1","sha1\":\"2ef40de3ee067e434fd582503e50e11741006b3e\"}")
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
              allow(command).to receive(:file_checksum).and_return("ae58f89c93073e0c455028a1c8216b3fc55fe672")
              allow(director).to receive(:uuid).and_return('123456-789abcdef')
              allow(director).to receive(:get_task_result_log).and_return('{"blobstore_id":"5619c1c7-da61-470c-b791-51cac0bf9935","sha1":"ae58f89c93073e0c455028a1c8216b3fc55fe672"}')
              allow(director).to receive(:download_resource).and_return(spec_asset('test_release-dev_version.tgz'))
            end

            context 'when export release command args are not following required format (string with slash in the middle)' do
              before {
                allow(client).to receive(:export).with('export_support', 'release', '1', 'centos-7', '0000')
              }

              it 'should raise an ArgumentError exception' do
                expect {command.export('release 1', 'centos-7 0000')}.to raise_error(ArgumentError, '"release 1" must be in the form name/version')
              end
            end

            context 'when export release command is executed' do
              it 'makes the proper request' do
                expect(client).to receive(:export).with('export_support', 'release', '1', 'centos-7', '0000')
                command.export('release/1', 'centos-7/0000')
              end
            end

            context 'when the task status is :failed' do
              before {
                allow(client).to receive(:export).and_return([:failed, some_task_id])
              }

              it 'changes the exit status to 1' do
                expect {
                  command.export('release/1', 'centos-7/0000')
                }.to change { command.exit_code }.from(0).to(1)
              end
            end

            context 'when the task is done' do
              context 'when the task status is :done' do
                before {
                  allow(client).to receive(:export).and_return([:done, some_task_id])
                  allow(director).to receive(:get_task_result_log).and_return('{"blobstore_id":"5619c1c7-da61-470c-b791-51cac0bf9935","sha1":"ae58f89c93073e0c455028a1c8216b3fc55fe672"}')
                  allow(director).to receive(:download_resource).and_return(spec_asset('test_release-dev_version.tgz'))
                  allow(FileUtils).to receive(:move)
                }

                after {
                  FileUtils.remove_file("#{Dir.pwd}/release-release-1-on-centos-7-stemcell-0000.tgz", true)
                }

                it 'returns exit status 0' do
                  command.export('release/1', 'centos-7/0000')
                  expect(command.exit_code).to eq(0)
                end

                it 'downloads the tarball' do
                  allow(command).to receive(:file_checksum).and_return("ae58f89c93073e0c455028a1c8216b3fc55fe672")
                  command.export('release/1', 'centos-7/0000')
                  out = Bosh::Cli::Config.output.string
                  expect(out).to match /downloaded/
                end

                it 'downloads the tarball and raise an error if sha1 dont match' do
                  allow(command).to receive(:file_checksum).and_return("mismatch")
                  expect {
                    command.export('release/1', 'centos-7/0000')
                  }.to raise_error
                end
              end
            end
          end
        end
      end
    end
  end
end
