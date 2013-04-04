require 'spec_helper'

describe Bosh::Cli::Command::User do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }

  before do
    command.stub(:director).and_return(director)
  end

  context "when interactive" do
    before do
      command.options[:non_interactive] = false
      command.options[:username] = 'admin'
      command.options[:password] = 'admin'
      command.options[:target] = 'http://example.org'
    end

    it "asks for username, password, and verify password" do
      command.should_receive(:ask).with("Enter new username: ").and_return('bosh')
      command.should_receive(:ask).with("Enter new password: ").and_return('b05h')
      command.should_receive(:ask).with("Verify new password: ").and_return('b05h')

      director.should_receive(:create_user).with("bosh", "b05h").and_return(true)

      command.create
    end

    it "fails if confirmation password does not match" do
      command.should_receive(:ask).with("Enter new username: ").and_return('bosh')
      command.should_receive(:ask).with("Enter new password: ").and_return('b05h')
      command.should_receive(:ask).with("Verify new password: ").and_return('something different')

      director.should_not_receive(:create_user)

      expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Passwords do not match')
    end

    it "fails if username is blank" do
      command.should_receive(:ask).with("Enter new username: ").and_return('')
      command.should_receive(:ask).with("Enter new password: ").and_return('b05h')
      command.should_receive(:ask).with("Verify new password: ").and_return('b05h')

      director.should_not_receive(:create_user)

      expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Please enter username and password')
    end

    it "fails if password is blank" do
      command.should_receive(:ask).with("Enter new username: ").and_return('bosh')
      command.should_receive(:ask).with("Enter new password: ").and_return('')
      command.should_receive(:ask).with("Verify new password: ").and_return('')

      director.should_not_receive(:create_user)

      expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Please enter username and password')
    end


    it "fails if director does not successfully create the user" do
      command.should_receive(:ask).with("Enter new username: ").and_return('bosh')
      command.should_receive(:ask).with("Enter new password: ").and_return('b05h')
      command.should_receive(:ask).with("Verify new password: ").and_return('b05h')

      director.should_receive(:create_user).with("bosh", "b05h").and_return(false)

      expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Error creating user')
    end

  end
end