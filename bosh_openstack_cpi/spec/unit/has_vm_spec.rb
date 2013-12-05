# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "has_vm? returns true if OpenStack server exists" do
    server = double("server", :id => "i-foobar", :state => :active)
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.has_vm?("i-foobar").should be(true)
  end

  it "has_vm? returns false if OpenStack server doesn't exists" do
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(nil)
    end
    cloud.has_vm?("i-foobar").should be(false)
  end

  it "has_vm? returns false if OpenStack server state is :terminated" do
    server = double("server", :id => "i-foobar", :state => :terminated)
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.has_vm?("i-foobar").should be(false)
  end

  it "has_vm? returns false if OpenStack server state is :deleted" do
    server = double("server", :id => "i-foobar", :state => :deleted)
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.has_vm?("i-foobar").should be(false)
  end
end
