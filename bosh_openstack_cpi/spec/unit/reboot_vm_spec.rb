# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before :each do
    @server = double("server", :id => "i-foobar")

    @cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(@server)
    end
  end

  it "reboots an OpenStack server (CPI call picks soft reboot)" do
    @cloud.should_receive(:soft_reboot).with(@server)
    @cloud.reboot_vm("i-foobar")
  end

  it "soft reboots an OpenStack server" do
    @server.should_receive(:reboot)
    @cloud.should_receive(:wait_resource).with(@server, :active, :state)
    @cloud.send(:soft_reboot, @server)
  end

  it "hard reboots an OpenStack server" do
    @server.should_receive(:reboot)
    @cloud.should_receive(:wait_resource).with(@server, :active, :state)
    @cloud.send(:hard_reboot, @server)
  end

end
