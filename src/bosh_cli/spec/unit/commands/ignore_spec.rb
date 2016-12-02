require 'spec_helper'

module Bosh::Cli
  describe Command::Ignore do
    let(:command) { Command::Ignore.new }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }
    let(:deployment) { 'dep1' }
    let(:target) { 'http://example.org' }
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
      allow(command).to receive(:director).and_return(director)
      allow(command).to receive(:nl)
      command.options[:target] = target
      allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, hash: deployment_manifest, name: 'dep1'))
      allow(command).to receive(:show_current_state)
    end

    describe 'usage' do
      it 'should show ignore usage when calling ignore without params' do
        expect(Config.commands['ignore instance'].usage_with_params).to eq('ignore instance <name_and_id>')
      end

      it 'should show unignore usage when calling unignore without params' do
        expect(Config.commands['unignore instance'].usage_with_params).to eq('unignore instance <name_and_id>')
      end
    end

    context 'when not logged in' do
      before { allow(command).to receive(:logged_in?) { false } }

      it 'requires user to be authenticated when calling ignore' do
        expect {
          command.ignore('instance/id')
        }.to raise_error(Bosh::Cli::CliError, "Please log in first")
      end

      it 'requires user to be authenticated when calling unignore' do
        expect {
          command.unignore('instance/id')
        }.to raise_error(Bosh::Cli::CliError, "Please log in first")
      end
    end

    context 'when logged in' do
      before { allow(command).to receive(:logged_in?) { true } }

      context 'when user did not choose deployment' do
        before { allow(command).to receive(:deployment).and_return(nil) }

        it 'raises an error with choose deployment message when ignore is called without deployment' do
          expect {
            command.ignore('instance/id')
          }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
        end

        it 'raises an error with choose deployment message when unignore is called without deployment' do
          expect {
            command.unignore('instance/id')
          }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
        end
      end

      context 'when "name_and_id" is invalid' do
        before { allow(command).to receive(:deployment).and_return('fake-dep-path') }

        it 'should raise an ArgumentError exception when ignore param is nil' do
          expect {
            command.ignore(nil)
          }.to raise_error(ArgumentError, 'str must not be nil')
        end

        it 'should raise an ArgumentError exception when unignore param is nil' do
          expect {
            command.unignore(nil)
          }.to raise_error(ArgumentError, 'str must not be nil')
        end

        it 'should raise an ArgumentError exception when ignore param is missing uuid' do
          expect {
            command.ignore("instance")
          }.to raise_error(ArgumentError, '"instance" must be in the form name/id')
        end

        it 'should raise an ArgumentError exception when unignore param is missing uuid' do
          expect {
            command.unignore("instance")
          }.to raise_error(ArgumentError, '"instance" must be in the form name/id')
        end
      end

      context 'when "name_and_id" is valid' do
        before { allow(command).to receive(:deployment).and_return('fake-dep-path') }

        describe 'changing the state' do
          it 'should request the ignore state to be true' do
            expect(director).to receive(:change_instance_ignore_state).with(deployment, 'dea', '6B0DE211-5EAA-4D13-90E6-34D47D2C1284', true)
            command.ignore('dea/6B0DE211-5EAA-4D13-90E6-34D47D2C1284')
          end

          it 'should request the ignore state to be false' do
            expect(director).to receive(:change_instance_ignore_state).with(deployment, 'dea', '38259D3C-67EB-423D-9D60-9AA75AC984FA', false)
            command.unignore('dea/38259D3C-67EB-423D-9D60-9AA75AC984FA')
          end
        end
      end
    end
  end
end
