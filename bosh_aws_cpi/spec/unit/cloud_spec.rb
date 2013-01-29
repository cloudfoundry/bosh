# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      cloud = Bosh::Clouds::Provider.create(:aws, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::AwsCloud::Cloud)
    end

  end

  internal_to Bosh::AwsCloud::Cloud do

    it "should not find stemcell-copy" do
      cloud = Bosh::Clouds::Provider.create(:aws, mock_cloud_options)
      cloud.has_stemcell_copy("/usr/bin:/usr/sbin").should be_nil
    end

    it "should find stemcell-copy" do
      cloud = Bosh::Clouds::Provider.create(:aws, mock_cloud_options)
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
      cloud.has_stemcell_copy(path).should_not be_nil
    end

  end

end
