require 'spec_helper'

describe Bosh::Cli::UaaLoginStrategy do
  describe '#login' do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, ask: nil, ask_password: nil, say_green: nil) }
    let(:uaa) { instance_double(Bosh::Cli::Client::Uaa::Client, login: nil) }
    let(:config) { instance_double(Bosh::Cli::Config, set_credentials: nil, save: nil) }
    let(:target) { 'some target' }

    context 'when in interactive mode' do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, config, true) }

      before do
        allow(uaa).to receive(:prompts) { [
          Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
          Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
          Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'Super secure one-time code'),
        ] }

        allow(uaa).to receive(:login).
          with('username' => 'user', 'password' => 'pass', 'passcode' => '1234').
          and_return(Bosh::Cli::Client::Uaa::AccessInfo.new('user', access_token))
      end
      let(:access_token) { 'access token' }

      it 'prompts for UAA credentials' do
        expect(terminal).to receive(:ask).with('Email: ') { 'user' }
        expect(terminal).to receive(:ask_password).with('Password: ')  { 'pass' }
        expect(terminal).to receive(:ask_password).with('Super secure one-time code: ') { '1234' }

        login_strategy.login(target, '', '')
      end

      context 'given valid credentials' do
        before do
          allow(terminal).to receive(:ask).with('Email: ') { 'user' }
          allow(terminal).to receive(:ask_password).with('Password: ') { 'pass' }
          allow(terminal).to receive(:ask_password).with('Super secure one-time code: ') { '1234' }
        end

        it "says you're logged" do
          login_strategy.login(target)

          expect(terminal).to have_received(:say_green).with("Logged in as `user'")
        end

        it 'updates the config' do
          login_strategy.login(target)

          expect(config).to have_received(:set_credentials).with(target, {
            'token' => 'access token'
          })
          expect(config).to have_received(:save)
        end

        context 'when token is not returned' do
          let(:access_token) { nil }

          it 'does not update config' do
            login_strategy.login(target)

            expect(config).to_not have_received(:set_credentials)
            expect(config).to_not have_received(:save)
          end
        end
      end

      context 'when credentials are invalid' do
        before do
          allow(terminal).to receive(:ask).with('Email: ') { 'bad-user' }
          allow(terminal).to receive(:ask_password).with('Password: ') { 'bad-pass' }
          allow(terminal).to receive(:ask_password).with('Super secure one-time code: ') { '1234' }
        end

        it 'prints an error' do
          expect {
            login_strategy.login(target)
          }.to raise_error(Bosh::Cli::CliError, 'Failed to log in')
        end
      end
    end

    context 'non-interactive' do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, config, false) }
      it 'raises an error' do
        expect {
          login_strategy.login(target, '', '')
        }.to raise_error(Bosh::Cli::CliError, 'Non-interactive UAA login is not supported.')
      end
    end
  end
end
