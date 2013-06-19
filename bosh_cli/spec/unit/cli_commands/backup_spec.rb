require "spec_helper"

describe Bosh::Cli::Command::Backup do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }

  before do
    command.stub(:director).and_return(director)
  end

  describe "backup" do
    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.backup }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when nothing is targetted" do
      before do
        command.stub(:target => nil)
        command.stub(:logged_in? => true)
      end

      it "fails" do
        expect { command.backup }.to raise_error(Bosh::Cli::CliError, 'Please choose target first')
      end
    end

    context "when a user is logged in" do
      before do
        command.options[:username] = "bosh"
        command.options[:password] = "b05h"
        command.options[:target] = "http://bosh-target.example.com"

        FileUtils.stub(:mv)
      end

      it "logs the path where the backup was put" do
        dest = "/tmp/path/to/backup.tgz"

        Dir.mktmpdir("backup") do |temp|
          command.director.stub(create_backup: [:done, 42])
          command.director.stub(fetch_backup: temp)
          command.should_receive(:say).with("Backup of BOSH director was put in `#{dest}'.")

          command.backup(dest)
        end
      end

      context "when the user provides a destination path" do
        it "backs up to provided path" do
          dest = "/tmp/path/to/backup.tgz"
          Dir.mktmpdir("backup") do |temp|
            command.director.should_receive(:create_backup).and_return [:done, 42]
            command.director.should_receive(:fetch_backup).and_return temp
            FileUtils.should_receive(:mv).with(temp, dest).and_return(true)
            command.backup(dest)
          end
        end
      end

      context "when the user does not provide a destination path" do
        it "backs up the the current working directory" do
          Dir.mktmpdir("backup") do |temp|
            command.director.should_receive(:create_backup).and_return [:done, 42]
            command.director.should_receive(:fetch_backup).and_return temp
            FileUtils.should_receive(:mv).with(temp, "#{Dir.pwd}/bosh_backup.tgz").and_return(true)
            command.backup
          end
        end
      end
    end
  end
end