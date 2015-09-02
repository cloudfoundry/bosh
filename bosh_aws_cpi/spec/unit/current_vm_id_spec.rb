# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"
require 'webmock/rspec'

describe Bosh::AwsCloud::Cloud do

  describe "#current_vm_id" do
    let(:options) {
      {
          "aws" => {
              "default_availability_zone" => "foo",
              "region" => "bar",
              "access_key_id" => "access",
              "secret_access_key" => "secret",
              "default_key_name" => "sesame"
          },
          "registry" => {
              "endpoint" => "endpoint",
              "user" => "user",
              "password" => "password"
          },
          "agent" => {
              "baz" => "qux"
          }
      }
    }

    let(:cloud) { described_class.new(options) }

    before do
      stub_request(:post, "https://ec2.bar.amazonaws.com/").
          with(:body => /^Action=DescribeRegions.*$/).
          to_return(:status => 200, :body => "", :headers => {})
    end

    let(:fake_instance_id) {"i-xxxxxxxx"}

    it "should make a call to AWS and return the correct vm id" do
      stub_request(:get, "http://169.254.169.254/latest/meta-data/instance-id/")
        .to_return(:body => fake_instance_id)
      expect(cloud.current_vm_id).to eq(fake_instance_id)
    end
  end
end
