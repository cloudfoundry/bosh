# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  before :each do
    @server = double("server", :id => "i-foobar")

    @cloud = mock_cloud(mock_cloud_options) do |compute|
      compute.servers.stub(:get).with("i-foobar").and_return(@server)
    end
  end

  it "reboots an CloudStack server (CPI call picks soft reboot)" do
    @cloud.should_receive(:soft_reboot).with(@server)
    @cloud.reboot_vm("i-foobar")
  end

  it "soft reboots an CloudStack server" do
    job = generate_job
    @server.should_receive(:reboot).and_return(job)
    @cloud.should_receive(:wait_job).with(job)
    @cloud.send(:soft_reboot, @server)
  end

  it "hard reboots an CloudStack server" do
    job = generate_job
    @server.should_receive(:stop).with({:force => true}).and_return(job)
    @cloud.should_receive(:wait_job).with(job)
    job = generate_job
    @server.should_receive(:start).and_return(job)
    @cloud.should_receive(:wait_job).with(job)
    @cloud.send(:hard_reboot, @server)
  end

end
