# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

class FakeDeploymentManager
  def find_by_name(name)
    @deployment
  end

  def deployment=(deployment)
    @deployment = deployment
  end
end

describe Bosh::Director::Api::ProblemManager do
  !let(:deployment) { BD::Models::Deployment.make(:name => "mycloud") }
  let(:deployment_manager) { FakeDeploymentManager.new }
  let(:manager) { described_class.new(deployment_manager) }

  describe "scan and fix" do
    let(:task) { double('task', :id => 42).as_null_object }

    before do
      deployment_manager.deployment = deployment
      manager.stub(:create_task).and_return(task)
    end

    context "when fixing stateful nodes" do
      before :each do
        Bosh::Director::Config.fix_stateful_nodes = true
      end

      it "returns a task" do
        Resque.stub(:enqueue)

        expect(manager.scan_and_fix("admin", deployment.name, [])).to eq task
      end

      it "enqueues a task" do
        Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::ScanAndFix, 42, "mycloud", [], true)
        manager.scan_and_fix("admin", deployment.name, [])
      end
    end

    context "when not fixing stateful nodes" do
      before :each do
        Bosh::Director::Config.fix_stateful_nodes = false
      end

      it "returns a task" do
        Resque.stub(:enqueue)

        expect(manager.scan_and_fix("admin", deployment.name, [])).to eq task
      end

      it "enqueues a task" do
        Resque.should_receive(:enqueue).with(BD::Jobs::CloudCheck::ScanAndFix, 42, "mycloud", [], false)
        manager.scan_and_fix("admin", deployment.name, [])
      end
    end
  end
end
