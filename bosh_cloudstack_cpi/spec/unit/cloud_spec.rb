# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      compute = double('compute')
      Fog::Compute.stub(:new).and_return(compute)
      zone = double('zone', :network_type => :basic)
      compute.stub_chain(:zones, :find).and_return(zone)
      cloud = Bosh::Clouds::Provider.create(:cloudstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::CloudStackCloud::Cloud)
    end

    it "raises ArgumentError on initializing with blank options" do
      options = Hash.new("options")
      expect {
        Bosh::CloudStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid CloudStack configuration/)
    end

    it "raises ArgumentError on initializing with non Hash options" do
      options = "this is a string"
      expect {
        Bosh::CloudStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid CloudStack configuration/)
    end

    it "raises a CloudError exception if cannot connect to the CloudStack Compute API" do
      Fog::Compute.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      expect {
        Bosh::Clouds::Provider.create(:cloudstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the CloudStack Compute API. Check task debug log for details.")
    end

  end
end
