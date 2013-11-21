# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do
  let(:server) { double("server", :id => "i-foobar") }

  before :each do
    @cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-foobar").and_return(server)
    end
  end

  it "should set metadata" do
    metadata = {:job => "job", :index => "index"}

    Bosh::CloudStackCloud::TagManager.should_receive(:tag).with(server, :job, "job")
    Bosh::CloudStackCloud::TagManager.should_receive(:tag).with(server, :index, "index")

    @cloud.set_vm_metadata("i-foobar", metadata)
  end
end
