# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do

  before :each do
    @instance = double("instance", :id => "i-foobar")

    @cloud = mock_cloud(mock_cloud_options) do |ec2|
      ec2.instances.stub(:[]).with("i-foobar").and_return(@instance)
    end
  end

  it "reboots an EC2 instance (CPI call picks soft reboot)" do
    @cloud.should_receive(:soft_reboot).with(@instance)
    @cloud.reboot_vm("i-foobar")
  end

  it "soft reboots an EC2 instance" do
    @instance.should_receive(:reboot)
    @cloud.send(:soft_reboot, @instance)
  end

  it "hard reboots an EC2 instance" do
    # N.B. This requires ebs-store instance
    @instance.should_receive(:stop).ordered
    @instance.should_receive(:status).ordered.and_return(:stopping)
    @cloud.should_receive(:wait_resource).
      with(@instance, :stopping, :stopped).ordered

    @instance.should_receive(:start)
    @instance.should_receive(:status).and_return(:starting)
    @cloud.should_receive(:wait_resource).ordered.
      with(@instance, :starting, :running)

    @cloud.send(:hard_reboot, @instance)
  end

end
