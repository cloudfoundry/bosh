require 'cli/uaa_login_service'
require 'cli/terminal'
require 'cli/config'
require 'cli/client/uaa'

describe Bosh::Cli::UaaLoginService do
  describe "#login" do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, ask: nil, ask_password: nil) }
    let(:uaa) { instance_double(Bosh::Cli::Client::Uaa) }
    let(:config) { instance_double(Bosh::Cli::Config) }
    let(:target) { 'some target' }

    context "interactive" do
      let(:login_service) { Bosh::Cli::UaaLoginService.new(terminal, uaa, config, true) }

      it "asks for the info UAA needs" do
        allow(uaa).to receive(:prompts) { [
          Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
          Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
          Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'Super secure one-time code'),
        ] }

        login_service.login(target, '', '')

        expect(terminal).to have_received(:ask).with("Email: ")
        expect(terminal).to have_received(:ask_password).with("Password: ")
        expect(terminal).to have_received(:ask_password).with("Super secure one-time code: ")
      end
    end

    context "non-interactive" do
      let(:login_service) { Bosh::Cli::UaaLoginService.new(terminal, uaa, config, false) }
      it "raises an error" do
        expect {
          login_service.login(target, '', '')
        }.to raise_error(Bosh::Cli::CliError, "Non-interactive UAA login is not supported.") #TODO: red
      end
    end
  end
end
