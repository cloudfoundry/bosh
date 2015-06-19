require 'spec_helper'

describe Bosh::Cli::Command::User do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  before do
    allow(command).to receive(:director).and_return(director)
    target = 'https://127.0.0.1:8080'
    stub_request(:get, "#{target}/info").to_return(body: '{}')
    command.options[:target] = target
    allow(command).to receive(:show_current_state)
  end

  describe "creating a new user" do
    context "when interactive" do
      before do
        command.options[:non_interactive] = false
        command.options[:username] = 'admin'
        command.options[:password] = 'admin'
      end

      it "asks for username, password, and verify password" do
        expect(command).to receive(:ask).with("Enter new username: ").and_return('bosh')
        expect(command).to receive(:ask).with("Enter new password: ").and_return('b05h')
        expect(command).to receive(:ask).with("Verify new password: ").and_return('b05h')

        expect(director).to receive(:create_user).with("bosh", "b05h").and_return(true)

        command.create
      end

      it "fails if confirmation password does not match" do
        expect(command).to receive(:ask).with("Enter new username: ").and_return('bosh')
        expect(command).to receive(:ask).with("Enter new password: ").and_return('b05h')
        expect(command).to receive(:ask).with("Verify new password: ").and_return('something different')

        expect(director).not_to receive(:create_user)

        expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Passwords do not match')
      end

      it "fails if username is blank" do
        expect(command).to receive(:ask).with("Enter new username: ").and_return('')
        expect(command).to receive(:ask).with("Enter new password: ").and_return('b05h')
        expect(command).to receive(:ask).with("Verify new password: ").and_return('b05h')

        expect(director).not_to receive(:create_user)

        expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Please enter username and password')
      end

      it "fails if password is blank" do
        expect(command).to receive(:ask).with("Enter new username: ").and_return('bosh')
        expect(command).to receive(:ask).with("Enter new password: ").and_return('')
        expect(command).to receive(:ask).with("Verify new password: ").and_return('')

        expect(director).not_to receive(:create_user)

        expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Please enter username and password')
      end

      it "fails if director does not successfully create the user" do
        expect(command).to receive(:ask).with("Enter new username: ").and_return('bosh')
        expect(command).to receive(:ask).with("Enter new password: ").and_return('b05h')
        expect(command).to receive(:ask).with("Verify new password: ").and_return('b05h')

        expect(director).to receive(:create_user).with("bosh", "b05h").and_return(false)

        expect { command.create }.to raise_error(Bosh::Cli::CliError, 'Error creating user')
      end
    end
  end

  describe "deleting a user" do
    context "when user is not logged in" do
      before do
        allow(command).to receive_messages(:logged_in? => false)
      end

      it "fails" do
        expect { command.delete }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when nothing is targetted" do
      before do
        allow(command).to receive_messages(:target => nil)
        allow(command).to receive_messages(:logged_in? => true)
      end

      it "fails" do
        expect { command.delete }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
      end
    end

    context "when the user is logged in" do
      let(:user_to_delete) { "tom" }

      before do
        command.options[:username] = "bosh"
        command.options[:password] = "b05h"
      end

      context "when the user deletion fails" do
        before do
          command.options[:non_interactive] = true
        end

        it "throws an error message" do
          expect(director).to receive(:delete_user).and_return(false)
          expect { command.delete(user_to_delete) }.to raise_error(Bosh::Cli::CliError, "Unable to delete user")
        end
      end

      context "when interactive" do
        before do
          command.options[:non_interactive] = false
        end

        context "when the user confirms the user deletion" do
          it "deletes the user" do
            expect(command).
              to receive(:confirmed?).
              with("Are you sure you would like to delete the user `#{user_to_delete}'?").
              and_return(true)

            expect(director).to receive(:delete_user).with(user_to_delete).and_return(true)
            expect(command).to receive(:say).with("User `#{user_to_delete}' has been deleted")

            command.delete(user_to_delete)
          end
        end

        context "when the user does not confirm the user deletion" do
          it "does not delete the user" do
            expect(command).
              to receive(:confirmed?).
              with("Are you sure you would like to delete the user `#{user_to_delete}'?").
              and_return(false)

            expect(director).not_to receive(:delete_user)
            command.delete(user_to_delete)
          end
        end

        context "when the user is not provided" do
          it "asks for the username" do
            expect(command).to receive(:ask).with("Username to delete: ").and_return("r00t")
            expect(command).
              to receive(:confirmed?).
              with("Are you sure you would like to delete the user `r00t'?").
              and_return(true)
            expect(director).to receive(:delete_user).with("r00t").and_return(true)

            command.delete
          end
        end
      end

      context "when non interactive" do
        before do
          command.options[:non_interactive] = true
        end

        context "when the user is not provided" do
          it "fails" do
            expect { command.delete }.to raise_error(Bosh::Cli::CliError, "Please provide a username to delete")
            expect { command.delete("") }.to raise_error(Bosh::Cli::CliError, "Please provide a username to delete")
          end
        end
      end
    end
  end
end
