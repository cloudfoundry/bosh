require 'spec_helper'

describe Bosh::Cli::Command::Backup do
  let(:command) { described_class.new }
  let(:director_name) { 'mini-bosh' }
  let(:target) { 'https://127.0.0.1:8080' }

  before do
    director_status = { 'name' => director_name }
    stub_request(:get, "#{target}/info").to_return(body: JSON.dump(director_status))
  end

  describe 'backup' do
    context 'when user is not logged in' do
      before do
        allow(command).to receive_messages(:logged_in? => false)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      it 'fails' do
        expect { command.backup }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context 'when nothing is targetted' do
      before do
        allow(command).to receive_messages(:target => nil)
        allow(command).to receive_messages(:logged_in? => true)
      end

      it 'fails' do
        expect { command.backup }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
      end
    end

    context 'when a user is logged in' do
      let!(:download_path) { Dir.mktmpdir('backup') }
      let(:dest) { '/a/path/to/a/backup.tgz' }

      before do
        command.options[:username] = 'bosh'
        command.options[:password] = 'b05h'
        command.options[:target] = target
        allow(command).to receive(:show_current_state)

        allow(Bosh::Cli::BackupDestinationPath).to receive_message_chain(:new, :create_from_path) { dest }

        allow(FileUtils).to receive(:mv)
      end

      after do
        FileUtils.rm_rf(download_path)
      end

      it 'logs the path where the backup was put' do
        expect(command.director).to receive(:create_backup).and_return [:done, 42]
        expect(command.director).to receive(:fetch_backup).and_return download_path

        expect(command).to receive(:say).with("Backup of BOSH director was put in `#{dest}'.")
        command.backup(dest)
      end

      it 'moves the backup to the computed path' do
        expect(command.director).to receive(:create_backup).and_return [:done, 42]
        expect(command.director).to receive(:fetch_backup).and_return download_path

        expect(FileUtils).to receive(:mv).with(download_path, dest).and_return(true)
        command.backup(dest)
      end

      context 'when the file already exists' do
        before do
          allow(File).to receive(:exists?).with(anything).and_call_original
          allow(File).to receive(:exists?).with(dest).and_return(true)
        end

        context 'when the --force option is true' do
          before do
            command.options[:force] = true
          end

          it 'overwrites the file' do
            expect(command.director).to receive(:create_backup).and_return [:done, 42]
            expect(command.director).to receive(:fetch_backup).and_return download_path

            expect(FileUtils).to receive(:mv).with(download_path, dest).and_return(true)
            command.backup(dest)
          end
        end

        context 'when the --force option is false' do
          before do
            command.options[:force] = false
          end

          it 'does not overwrite the file and tells the user about the --force option' do
            expect(FileUtils).not_to receive(:mv).with(download_path, dest)

            expect {
              command.backup(dest)
            }.to raise_error(Bosh::Cli::CliError,
                             "There is already an existing file at `#{dest}'. " +
                               'To overwrite it use the --force option.')
          end
        end
      end
    end
  end
end
