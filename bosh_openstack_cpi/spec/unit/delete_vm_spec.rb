# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before(:each) do
     @registry = mock_registry
   end

  it "deletes an OpenStack server" do
    server = double("server", :id => "i-foobar", :name => "i-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with("i-foobar").and_return(server)
    end

    expect(server).to receive(:destroy).and_return(true)
    expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

    expect(@registry).to receive(:delete_settings).with("i-foobar")

    cloud.delete_vm("i-foobar")
  end
end
