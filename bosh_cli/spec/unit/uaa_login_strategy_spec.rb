require 'spec_helper'

describe Bosh::Cli::UaaLoginStrategy do
  describe '#login' do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, ask: nil, ask_password: nil, say_green: nil) }
    let(:uaa) { instance_double(Bosh::Cli::Client::Uaa::Client) }
    let(:config) { instance_double(Bosh::Cli::Config, set_credentials: nil, save: nil) }
    let(:target) { 'some target' }

    context 'when in interactive mode' do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, true) }

      before do
        allow(uaa).to receive(:prompts) { [
          Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
          Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
          Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'Super secure one-time code'),
        ] }

        allow(uaa).to receive(:access_info).
          with({'username' => 'user', 'password' => 'pass', 'passcode' => '1234'}).
          and_return(access_info)
      end

      let(:access_info) do
        token_decoder = Bosh::Cli::Client::Uaa::TokenDecoder.new
        token_info = CF::UAA::TokenInfo.new(access_token: 'access token')
        allow(token_decoder).to receive(:decode).with(token_info).and_return({'user_name' => 'user'})
        Bosh::Cli::Client::Uaa::PasswordAccessInfo.new(token_info, token_decoder)
      end

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

        it "says you're logged in" do
          login_strategy.login(target)

          expect(terminal).to have_received(:say_green).with("Logged in as `user'")
        end
      end

      context 'when credentials are invalid' do
        before do
          allow(terminal).to receive(:ask).with('Email: ') { 'bad-user' }
          allow(terminal).to receive(:ask_password).with('Password: ') { 'bad-pass' }
          allow(terminal).to receive(:ask_password).with('Super secure one-time code: ') { '1234' }
        end

        it 'prints an error' do
          expect(uaa).to receive(:access_info).
              with({'username' => 'bad-user', 'password' => 'bad-pass', 'passcode' => '1234'})
          expect {
            login_strategy.login(target)
          }.to raise_error(Bosh::Cli::CliError, 'Failed to log in')
        end
      end
    end

    context 'non-interactive' do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, false) }
      it 'raises an error' do
        expect {
          login_strategy.login(target, '', '')
        }.to raise_error(Bosh::Cli::CliError, 'Non-interactive UAA login is not supported.')
      end
    end
  end
end
