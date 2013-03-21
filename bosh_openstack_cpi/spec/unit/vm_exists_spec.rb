# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "vm_exists? returns true if OpenStack server exists" do
    server = double("server", :id => "i-foobar")
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.vm_exists?("i-foobar").should be_true
  end

  it "vm_exists? returns false if OpenStack server doesn't exists" do
    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(nil)
    end
    cloud.vm_exists?("i-foobar").should be_false
  end

end