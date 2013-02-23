# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do
  before :each do
    @server = double("server", :id => "i-foobar")
    @metadata = double("metadata")

    @cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).
        with("i-foobar").and_return(@server)
    end
  end

  it "should set metadata" do
    metadata = {:job => "job", :index => "index"}

    @server.should_receive(:metadata).and_return(@metadata, @metadata)
    @metadata.should_receive(:update).with(:job => "job")
    @metadata.should_receive(:update).with(:index => "index")

    @cloud.set_vm_metadata("i-foobar", metadata)
  end

  it "should set metadata with a nil value" do
    metadata = {:deployment => nil}

    @server.should_receive(:metadata).and_return(@metadata)
    @metadata.should_receive(:update).with(:deployment => "")

    @cloud.set_vm_metadata("i-foobar", metadata)
  end
end