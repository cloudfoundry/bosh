# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Snapshot do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }

  before do
    command.stub(:director).and_return(director)
  end

  describe "listing snapshot" do

    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.list }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when the user is logged in" do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = "http://bosh-target.example.com"
      end

      context "when there are snapshots" do
        let(:snapshots) {[
          { 'job' => 'job', 'index' => 0, 'snapshot_id' => 'snap0a', 'created_at' => Time.now, 'clean' => true }
        ]}

        it "list all snapshots for the deployment" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:list_snapshots).with("bosh", nil, nil).and_return(snapshots)

          command.list
        end

        it "list all snapshots for a job and index" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:list_snapshots).with("bosh", "foo", "0").and_return(snapshots)

          command.list("foo", "0")
        end
      end

      context "when there are no snapshots" do
        let(:snapshots) { [] }

        it "should not fail" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:list_snapshots).with("bosh", nil, nil).and_return(snapshots)

          command.list
        end
      end
    end
  end

  describe "taking a snapshot" do

    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.take("foo", "0") }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when the user is logged in" do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = "http://bosh-target.example.com"
      end

      context "for all deployment" do
        context "when interactive" do
          before do
            command.options[:non_interactive] = false
          end

          context "when the user confirms taking the snapshot" do
            it "deletes the snapshot" do
              command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
              command.should_receive(:confirmed?).with("Are you sure you want to take a snapshot of all deployment `bosh'?").and_return(true)

              director.should_receive(:take_snapshot).with("bosh", nil, nil)

              command.take()
            end
          end

          context "when the user does not confirms taking the snapshot" do
            it "does not delete the snapshot" do
              command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
              command.should_receive(:confirmed?).with("Are you sure you want to take a snapshot of all deployment `bosh'?").and_return(false)

              director.should_not_receive(:take_snapshot)

              command.take()
            end
          end
        end

        context "when non interactive" do
          before do
            command.options[:non_interactive] = true
          end

          it "takes the snapshot" do
            command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

            director.should_receive(:take_snapshot).with("bosh", nil, nil)

            command.take()
          end
        end
      end

      context "for a job and index" do
        it "takes the snapshot" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:take_snapshot).with("bosh", "foo", "0")

          command.take("foo", "0")
        end
      end
    end
  end

  describe "deleting a snapshot" do

    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.delete("snap0a") }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when the user is logged in" do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = "http://bosh-target.example.com"
      end

      context "when interactive" do
        before do
          command.options[:non_interactive] = false
        end

        context "when the user confirms the snapshot deletion" do
          it "deletes the snapshot" do
            command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
            command.should_receive(:confirmed?).with("Are you sure you want to delete snapshot `snap0a'?").and_return(true)

            director.should_receive(:delete_snapshot).with("bosh", "snap0a")

            command.delete("snap0a")
          end
        end

        context "when the user does not confirms the snapshot deletion" do
          it "does not delete the snapshot" do
            command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
            command.should_receive(:confirmed?).with("Are you sure you want to delete snapshot `snap0a'?").and_return(false)

            director.should_not_receive(:delete_snapshot)

            command.delete("snap0a")
          end
        end
      end

      context "when non interactive" do
        before do
          command.options[:non_interactive] = true
        end

        it "deletes the snapshot" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:delete_snapshot).with("bosh", "snap0a")

          command.delete("snap0a")
        end
      end
    end
  end

  describe "deleting all snapshots of a deployment" do

    context "when user is not logged in" do
      before do
        command.stub(:logged_in? => false)
        command.options[:target] = "http://bosh-target.example.com"
      end

      it "fails" do
        expect { command.delete_all }.to raise_error(Bosh::Cli::CliError, 'Please log in first')
      end
    end

    context "when the user is logged in" do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = "http://bosh-target.example.com"
      end

      context "when interactive" do
        before do
          command.options[:non_interactive] = false
        end

        context "when the user confirms the snapshot deletion" do
          it "deletes all snapshots" do
            command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
            command.should_receive(:confirmed?)
                .with("Are you sure you want to delete all snapshots of deployment `bosh'?").and_return(true)

            director.should_receive(:delete_all_snapshots).with("bosh")

            command.delete_all
          end
        end

        context "when the user does not confirms the snapshot deletion" do
          it "does not delete snapshots" do
            command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})
            command.should_receive(:confirmed?)
                .with("Are you sure you want to delete all snapshots of deployment `bosh'?").and_return(false)

            director.should_not_receive(:delete_all_snapshots)

            command.delete_all
          end
        end
      end

      context "when non interactive" do
        before do
          command.options[:non_interactive] = true
        end

        it "deletes all snapshots" do
          command.stub(:prepare_deployment_manifest).and_return({"name" => "bosh"})

          director.should_receive(:delete_all_snapshots).with("bosh")

          command.delete_all
        end
      end
    end
  end
end