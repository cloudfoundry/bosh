require 'fileutils'
require 'spec_helper'

describe Bosh::Cli::Command::ExportCompiledPackages do
  describe 'export compiled_packages' do
    subject(:command) { described_class.new }

    before { command.stub(director: director) }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }

    def perform
      command.perform(release, stemcell, download_dir)
    end

    let(:release) { 'release/1' }
    let(:stemcell) { 'stemcell/1' }
    let(:download_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(download_dir) }

    context 'when some director is targeted' do
      before { command.stub(target: 'fake-target') }

      context 'when the user is logged in' do
        before { command.stub(logged_in?: true) }

        context 'when nothing is there in download dir' do
          it 'downloads tgz and puts it in a correct place' do
            tmp_file = Tempfile.new('downloaded-file')
            tmp_file.write('downloaded-content')
            tmp_file.flush

            client = instance_double('Bosh::Cli::Client::CompiledPackagesClient')
            client.should_receive(:export).with('release', '1', 'stemcell', '1').and_return(tmp_file.path)
            Bosh::Cli::Client::CompiledPackagesClient.stub(:new).with(director).and_return(client)

            command.should_receive(:say).with(
              "Exported compiled packages to `#{download_dir}/release-1-stemcell-1.tgz'.")

            perform

            download_path = File.join(download_dir, 'release-1-stemcell-1.tgz')
            expect(File.read(download_path)).to eq('downloaded-content')
          end
        end

        context 'when another file is already there in download dir' do
          it 'fails with file exists error' do
            FileUtils.touch(File.join(download_dir, 'release-1-stemcell-1.tgz'))
            expect { perform }.to raise_error(
              Bosh::Cli::CliError, "File `#{download_dir}/release-1-stemcell-1.tgz' already exists.")
          end
        end

        context 'when download_dir points to non-existent directory' do
          it 'fails with missing directory name' do
            FileUtils.rm_rf(download_dir)
            expect { perform }.to raise_error(Bosh::Cli::CliError, "Directory `#{download_dir}' must exist.")
          end
        end
      end

      context 'when the user is not logged in' do
        it 'fails and tells the user to login' do
          command.stub(logged_in?: false)
          expect { perform }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
        end
      end
    end

    context 'when nothing is targeted' do
      it 'fails with required target error' do
        command.stub(target: nil)
        expect { perform }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
      end
    end
  end
end
