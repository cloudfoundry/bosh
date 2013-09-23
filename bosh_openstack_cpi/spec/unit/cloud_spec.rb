# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::OpenStackCloud::Cloud)
    end
    
    it "raises ArgumentError on initializing with blank options" do
    	options = Hash.new("options")
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end

    it "raises ArgumentError on initializing with non Hash options" do
    	options = "this is a string"
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end
    
    it "raises a CloudError exception if cannot connect to the OpenStack Compute API" do
      Fog::Compute.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      Fog::Image.stub(:new)
      expect {
        Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the OpenStack Compute API. Check task debug log for details.")
    end

    it "raises a CloudError exception if cannot connect to the OpenStack Image Service API" do
      Fog::Compute.stub(:new)
      Fog::Image.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      expect {
        Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the OpenStack Image Service API. Check task debug log for details.")
    end
    
    it "should implement ssl_verify_peer settings" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      ssl_options = mock_cloud_options.clone
      ssl_options["openstack"]["ssl_verify_peer"] = "false"
      Bosh::Clouds::Provider.create(:openstack, ssl_options)
      Excon.defaults[:ssl_verify_peer].should be_false
    end
    
  end
end
