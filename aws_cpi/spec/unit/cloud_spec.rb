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

    it "should throw ArgumentError if non Hash object is passed" do
      mock_options =''

      expect {
        Bosh::Clouds::Provider.create(:aws, mock_options)
      }.to raise_error ArgumentError
    end

    it "should throw ArgumentError if 'aws' key is not present in the options" do
      mock_options =
      {
          "registry" => {
          "endpoint" => "localhost:42288",
          "user" => "admin",
          "password" => "admin"
        },
        "agent" => {
          "foo" => "bar",
          "baz" => "zaz"
        }
      }

      expect {
        Bosh::Clouds::Provider.create(:aws, mock_options)
      }.to raise_error ArgumentError
    end

    it "should throw ArgumentError if 'registry' key is not present in the options" do
      mock_options =
      {
        "aws" => {
          "access_key_id" => MOCK_AWS_ACCESS_KEY_ID,
          "secret_access_key" => MOCK_AWS_SECRET_ACCESS_KEY
        },
        "agent" => {
          "foo" => "bar",
          "baz" => "zaz"
        }
      }

      expect {
        Bosh::Clouds::Provider.create(:aws, mock_options)
      }.to raise_error ArgumentError
    end

    it "should throw ArgumentError if aws access_key_id is not provided" do
      mock_options =
      {
        "aws" => {
          "secret_access_key" => MOCK_AWS_SECRET_ACCESS_KEY
        },
        "registry" => {
          "endpoint" => "localhost:42288",
          "user" => "admin",
          "password" => "admin"
        },
        "agent" => {
          "foo" => "bar",
          "baz" => "zaz"
        }
      }

      expect {
        Bosh::Clouds::Provider.create(:aws, mock_options)
      }.to raise_error ArgumentError
    end

    it "should throw ArgumentError if aws secret_access_key is not provided" do
      mock_options =
      {
        "aws" => {
          "access_key_id" => MOCK_AWS_ACCESS_KEY_ID,
        },
        "registry" => {
          "endpoint" => "localhost:42288",
          "user" => "admin",
          "password" => "admin"
        },
        "agent" => {
          "foo" => "bar",
          "baz" => "zaz"
        }
      }

      expect {
        Bosh::Clouds::Provider.create(:aws, mock_options)
      }.to raise_error ArgumentError
    end
  end

end
