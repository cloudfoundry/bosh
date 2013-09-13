require 'spec_helper'

describe Bosh::Cli::Command::User do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  before do
    command.stub(:director).and_return(director)
  end

  describe "creating a new user" do
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

  describe "deleting a user" do
    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.delete }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when nothing is targetted" do
      before do
        command.stub(:target => nil)
        command.stub(:logged_in? => true)
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
        command.options[:target] = "http://bosh-target.example.com"
      end

      context "when the user deletion fails" do
        before do
          command.options[:non_interactive] = true
        end

        it "throws an error message" do
          director.should_receive(:delete_user).and_return(false)
          expect { command.delete(user_to_delete) }.to raise_error(Bosh::Cli::CliError, "Unable to delete user")
        end
      end

      context "when interactive" do
        before do
          command.options[:non_interactive] = false
        end

        context "when the user confirms the user deletion" do
          it "deletes the user" do
            command.
              should_receive(:confirmed?).
              with("Are you sure you would like to delete the user `#{user_to_delete}'?").
              and_return(true)

            director.should_receive(:delete_user).with(user_to_delete).and_return(true)
            command.should_receive(:say).with("User `#{user_to_delete}' has been deleted")

            command.delete(user_to_delete)
          end
        end

        context "when the user does not confirm the user deletion" do
          it "does not delete the user" do
            command.
              should_receive(:confirmed?).
              with("Are you sure you would like to delete the user `#{user_to_delete}'?").
              and_return(false)

            director.should_not_receive(:delete_user)
            command.delete(user_to_delete)
          end
        end

        context "when the user is not provided" do
          it "asks for the username" do
            command.should_receive(:ask).with("Username to delete: ").and_return("r00t")
            command.
              should_receive(:confirmed?).
              with("Are you sure you would like to delete the user `r00t'?").
              and_return(true)
            director.should_receive(:delete_user).with("r00t").and_return(true)

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
