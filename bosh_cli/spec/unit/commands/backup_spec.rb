require 'spec_helper'

describe Bosh::Cli::Command::Backup do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  let(:director_name) { 'mini-bosh' }

  before do
    command.stub(:director).and_return(director)
    command.director.stub(:get_status).and_return({ 'name' => director_name })
  end

  describe 'backup' do
    context 'when user is not logged in' do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      it 'fails' do
        expect { command.backup }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context 'when nothing is targetted' do
      before do
        command.stub(:target => nil)
        command.stub(:logged_in? => true)
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
        command.options[:target] = 'http://bosh-target.example.com'

        Bosh::Cli::BackupDestinationPath.stub_chain(:new, :create_from_path) { dest }

        FileUtils.stub(:mv)
      end

      after do
        FileUtils.rm_rf(download_path)
      end

      it 'logs the path where the backup was put' do
        command.director.should_receive(:create_backup).and_return [:done, 42]
        command.director.should_receive(:fetch_backup).and_return download_path

        command.should_receive(:say).with("Backup of BOSH director was put in `#{dest}'.")
        command.backup(dest)
      end

      it 'moves the backup to the computed path' do
        command.director.should_receive(:create_backup).and_return [:done, 42]
        command.director.should_receive(:fetch_backup).and_return download_path

        FileUtils.should_receive(:mv).with(download_path, dest).and_return(true)
        command.backup(dest)
      end

      context 'when the file already exists' do
        before do
          File.stub(:exists?).with(anything).and_call_original
          File.stub(:exists?).with(dest).and_return(true)
        end

        context 'when the --force option is true' do
          before do
            command.options[:force] = true
          end

          it 'overwrites the file' do
            command.director.should_receive(:create_backup).and_return [:done, 42]
            command.director.should_receive(:fetch_backup).and_return download_path

            FileUtils.should_receive(:mv).with(download_path, dest).and_return(true)
            command.backup(dest)
          end
        end

        context 'when the --force option is false' do
          before do
            command.options[:force] = false
          end

          it 'does not overwrite the file and tells the user about the --force option' do
            FileUtils.should_not_receive(:mv).with(download_path, dest)

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