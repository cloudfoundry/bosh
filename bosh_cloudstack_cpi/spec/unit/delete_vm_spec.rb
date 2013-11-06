# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
     @registry = mock_registry
   end

  it "deletes an CloudStack server" do
    server = double("server", :id => "i-foobar", :name => "i-foobar")
    job = generate_job

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-foobar").and_return(server)
    end

    server.should_receive(:destroy).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    @registry.should_receive(:delete_settings).with("i-foobar")

    cloud.delete_vm("i-foobar")
  end
end
