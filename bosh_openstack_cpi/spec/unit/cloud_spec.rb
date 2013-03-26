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

  end
end
