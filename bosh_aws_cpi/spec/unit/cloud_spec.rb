# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

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

  describe "validating initialization options" do
    it "raises an error warning the user of all the missing required configurations" do
      expect {
        described_class.new(
            {
                "aws" => {
                    "access_key_id" => "keys to my heart",
                    "secret_access_key" => "open sesame"
                }
            }
        )
      }.to raise_error(ArgumentError, "missing configuration parameters > aws:region, registry:endpoint, registry:user, registry:password")
    end

    it "doesn't raise an error if all the required configuraitons are present" do
      expect {
        described_class.new(
            {
                "aws" => {
                    "access_key_id" => "keys to my heart",
                    "secret_access_key" => "open sesame",
                    "region" => "fupa"
                },
                "registry" => {
                    "user" => "abuser",
                    "password" => "hard2gess",
                    "endpoint" => "http://websites.com"
                }
            }
        )
      }.to_not raise_error
    end
  end

end
