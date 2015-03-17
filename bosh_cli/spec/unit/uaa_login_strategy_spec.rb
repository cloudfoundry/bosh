require 'spec_helper'

describe Bosh::Cli::UaaLoginStrategy do
  describe "#login" do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, ask: nil, ask_password: nil, say_green: nil) }
    let(:uaa) { instance_double(Bosh::Cli::Client::Uaa, login: nil) }
    let(:config) { instance_double(Bosh::Cli::Config, set_credentials: nil, save: nil) }
    let(:target) { 'some target' }

    context "when in interactive mode" do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, config, true) }

      before do
        allow(uaa).to receive(:prompts) { [
          Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
          Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
          Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'Super secure one-time code'),
        ] }
      end

      it "prompts for UAA credentials" do
        login_strategy.login(target, '', '')

        expect(terminal).to have_received(:ask).with("Email: ")
        expect(terminal).to have_received(:ask_password).with("Password: ")
        expect(terminal).to have_received(:ask_password).with("Super secure one-time code: ")
      end

      context "given valid credentials" do
        before do
          allow(uaa).to receive(:login) { {
            username: 'user',
            token: 'access token'
          } }

          allow(terminal).to receive(:ask).with('Email: ') { 'user' }
          allow(terminal).to receive(:ask_password).with('Password: ') { 'pass' }
          allow(terminal).to receive(:ask_password).with('Super secure one-time code: ') { '1234' }
        end

        it "says you're logged" do
          login_strategy.login(target)

          expect(terminal).to have_received(:say_green).with("Logged in as `user'")
        end

        it "updates the config" do
          login_strategy.login(target)

          expect(config).to have_received(:set_credentials).with(target, {
            token: 'access token'
          })
          expect(config).to have_received(:save)
        end
      end
    end

    context "non-interactive" do
      let(:login_strategy) { Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, config, false) }
      it "raises an error" do
        expect {
          login_strategy.login(target, '', '')
        }.to raise_error(Bosh::Cli::CliError, "Non-interactive UAA login is not supported.")
      end
    end
  end
end
