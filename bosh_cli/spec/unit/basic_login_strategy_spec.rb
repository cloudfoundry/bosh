require 'spec_helper'

describe Bosh::Cli::BasicLoginStrategy do
  context "interactive mode" do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, ask: nil, ask_password: nil, say_green: nil, say_red: nil) }
    let(:director) { instance_double(Bosh::Cli::Client::Director, login: true) }
    let(:config) { instance_double(Bosh::Cli::Config, set_credentials: nil, save: nil) }
    let(:target) { "http://some.director/url" }

    let(:login_strategy) { Bosh::Cli::BasicLoginStrategy.new(terminal, director, config, true) }

    it "asks for a username if the username is blank" do
      allow(terminal).to receive(:ask).with("Your username: ") { "user name" }
      allow(terminal).to receive(:ask_password).with("Enter password: ") { "password" }

      login_strategy.login(target, '', '')

      expect(terminal).to have_received(:ask).with("Your username: ")
    end

    it "doesn't ask for a username if the username is already given" do
      allow(terminal).to receive(:ask_password).with("Enter password: ") { "password" }

      login_strategy.login(target, 'user name', '')

      expect(terminal).to_not have_received(:ask)
    end

    it "asks for a password if one is not given" do
      allow(terminal).to receive(:ask_password).with("Enter password: ") { "password" }

      login_strategy.login(target, 'user name', '')

      expect(terminal).to have_received(:ask_password).with("Enter password: ")
      end

    it "doesn't ask for a password if one is not given" do
      login_strategy.login(target, 'user name', 'password')

      expect(terminal).to_not have_received(:ask_password)
    end

    it "errors if username entered is blank" do
      allow(terminal).to receive(:ask).with("Your username: ") { "" }

      expect {
        login_strategy.login(target, '', '')
      }.to raise_error(Bosh::Cli::CliError, "Please provide username and password")
    end

    it "errors if password entered is blank" do
      allow(terminal).to receive(:ask).with("Your username: ") { "user name" }
      allow(terminal).to receive(:ask_password).with("Enter password: ") { "" }

      expect {
        login_strategy.login(target, '', '')
      }.to raise_error(Bosh::Cli::CliError, "Please provide username and password")
    end

    it "says you're logged in if all went well" do
      allow(director).to receive(:login).with('user name', 'password') { true }

      login_strategy.login(target, 'user name', 'password')

      expect(terminal).to have_received(:say_green).with("Logged in as `user name'")
    end

    it "updates the config if all went well" do
      allow(director).to receive(:login).with('user name', 'password') { true }
      allow(config).to receive(:set_credentials)

      login_strategy.login(target, 'user name', 'password')

      expect(config).to have_received(:set_credentials).with(target, {
            'username' => 'user name',
            'password' => 'password'
          })
      expect(config).to have_received(:save)
    end

    it "doesn't update the config if login failed" do
      allow(director).to receive(:login).with('user name', 'password') { false }

      expect { login_strategy.login(target, 'user name', 'password') }.to raise_error Bosh::Cli::CliError

      expect(config).to_not have_received(:set_credentials)
      expect(config).to_not have_received(:save)
    end

    it "prints an error and retries with the same username if it can't log in" do
      allow(director).to receive(:login).with('user name', 'wrong password') { false }
      allow(director).to receive(:login).with('user name', 'right password') { true }
      allow(terminal).to receive(:ask_password).with("Enter password: ") { "right password" }

      login_strategy.login(target, 'user name', 'wrong password')

      expect(terminal).to have_received(:say_red).with("Cannot log in as `user name', please try again")
      expect(terminal).to_not have_received(:ask) # don't ask for username
      expect(terminal).to have_received(:say_green).with("Logged in as `user name'")
    end
  end

  context "non-interactive mode" do
    let(:terminal) { instance_double(Bosh::Cli::Terminal, say_green: nil, say_red: nil) }
    let(:director) { instance_double(Bosh::Cli::Client::Director, login: true) }
    let(:config) { instance_double(Bosh::Cli::Config, set_credentials: nil, save: nil) }
    let(:target) { "http://some.director/url" }

    let(:login_strategy) { Bosh::Cli::BasicLoginStrategy.new(terminal, director, config, false) }

    it "errors if username is blank" do
      expect {
        login_strategy.login(target, '', 'password')
      }.to raise_error(Bosh::Cli::CliError, "Please provide username and password")
    end

    it "errors if password is blank" do
      expect {
        login_strategy.login(target, 'user name', '')
      }.to raise_error(Bosh::Cli::CliError, "Please provide username and password")
    end

    it "says you're logged in if all went well" do
      allow(director).to receive(:login).with('user name', 'password') { true }

      login_strategy.login(target, 'user name', 'password')

      expect(terminal).to have_received(:say_green).with("Logged in as `user name'")
    end

    it "updates the config if all went well" do
      allow(director).to receive(:login).with('user name', 'password') { true }
      allow(config).to receive(:set_credentials)

      login_strategy.login(target, 'user name', 'password')

      expect(config).to have_received(:set_credentials).with(target, {
            'username' => 'user name',
            'password' => 'password'
          })
      expect(config).to have_received(:save)
    end

    it "doesn't update the config if login failed" do
      allow(director).to receive(:login).with('user name', 'password') { false }

      expect { login_strategy.login(target, 'user name', 'password') }.to raise_error Bosh::Cli::CliError

      expect(config).to_not have_received(:set_credentials)
      expect(config).to_not have_received(:save)
    end

    it "prints an error and fails if login fails" do
      allow(director).to receive(:login).with('user name', 'wrong password') { false }

      expect {
        login_strategy.login(target, 'user name', 'wrong password')
      }.to raise_error(Bosh::Cli::CliError, "Cannot log in as `user name'")
    end
  end
end
