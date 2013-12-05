# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "has_vm? returns true if CloudStack server exists" do
    server = double("server", :id => "i-foobar", :state => 'Ready')
    cloud = mock_cloud do |compute|
      compute.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.has_vm?("i-foobar").should be(true)
  end

  it "has_vm? returns false if CloudStack server doesn't exists" do
    cloud = mock_cloud do |compute|
      compute.servers.stub(:get).with("i-foobar").and_return(nil)
    end
    cloud.has_vm?("i-foobar").should be(false)
  end

  it "has_vm? returns false if CloudStack server state is 'Destroyed'" do
    server = double("server", :id => "i-foobar", :state => 'Destroyed')
    cloud = mock_cloud do |compute|
      compute.servers.stub(:get).with("i-foobar").and_return(server)
    end
    cloud.has_vm?("i-foobar").should be(false)
  end

end
