require 'spec_helper'

module Bosh::Cli
  describe Command::Restore do
    subject(:command) do
      Bosh::Cli::Command::Restore.new(nil, director)
    end

    let(:director) { double(Bosh::Cli::Client::Director) }

    before do
      allow(command).to receive(:show_current_state)
      allow(command).to receive_messages(:logged_in? => true)
      command.options[:target] = 'http://bosh-target.example.com'
      command.add_option(:non_interactive, true)
    end

    describe 'verify the validation of the db dump file' do
      it 'will raise error if the db dump file does not exist' do
        expect {
          command.restore('non_existing_db_dump_file')
        }.to raise_error(Bosh::Cli::CliError, /The file 'non_existing_db_dump_file' does not exist./)
      end
    end

    describe 'restore the director database' do
      let(:dump_file) { spec_asset('db_restore/db_dump_file') }

      it 'needs confirmation to restore database' do
        expect(director).not_to receive(:restore_db)
        expect(command).to receive(:ask)

        command.remove_option(:non_interactive)
        command.restore(dump_file)
      end

      it 'will upload the db dump file and restore the director database' do
        buffer = StringIO.new
        Bosh::Cli::Config.output = buffer

        expect(director).to receive(:restore_db).with(dump_file).and_return(202)
        expect(director).to receive(:check_director_restart).with(5, 600).and_return(true)

        expect {
          command.restore(dump_file)
        }.to_not raise_error

        buffer.rewind
        output = buffer.read

        expect(output).to include('Starting restore of BOSH director.')
        expect(output).to include('Restore done!')
      end

      it 'will report time out error if director is not restarted in time' do
        expect(director).to receive(:restore_db).with(dump_file).and_return(202)
        expect(director).to receive(:check_director_restart).with(5, 600).and_return(false)

        expect {
          command.restore(dump_file)
        }.to raise_error(Bosh::Cli::CliError, /Restore database timed out./)
      end

      it 'will report restore error if failed to restore database from director' do
        expect(director).to receive(:restore_db).with(dump_file).and_return(500)

        expect {
          command.restore(dump_file)
        }.to raise_error(Bosh::Cli::CliError, /Failed to restore the database, the status is '500'/)
      end
    end
  end
end
