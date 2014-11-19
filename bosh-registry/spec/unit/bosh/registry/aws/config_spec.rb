# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Registry::InstanceManager do

  describe "configuring AWS registry" do

    before(:each) do
      @config = valid_config
      @config["cloud"] = {
        "plugin" => "aws",
        "aws" => {
          "access_key_id" => "foo",
          "secret_access_key" => "bar",
          "region" => "foobar",
          "max_retries" => 5
        }
      }
    end

    it "validates presence of aws cloud option" do
      @config["cloud"].delete("aws")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid AWS configuration parameters/)
    end

    it "validates aws cloud option is a Hash" do
      @config["cloud"]["aws"] = "foobar"
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid AWS configuration parameters/)
    end

    it "validates presence of access_key_id cloud option" do
      @config["cloud"]["aws"].delete("access_key_id")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid AWS configuration parameters/)
    end

    it "validates presence of secret_access_key cloud option" do
      @config["cloud"]["aws"].delete("secret_access_key")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid AWS configuration parameters/)
    end

    it "validates presence of region cloud option" do
      @config["cloud"]["aws"].delete("region")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid AWS configuration parameters/)
    end

    it "passes optional parameters to EC2" do
      @config["cloud"]["aws"]["ssl_verify_peer"] = false
      @config["cloud"]["aws"]["ssl_ca_file"] = '/custom/cert/ca-certificates'
      @config["cloud"]["aws"]["ssl_ca_path"] = '/custom/cert/'

      instance_double('AWS::EC2')
      expect(AWS::EC2).to receive(:new) do |config|
        config[:ssl_verify_peer].should be false
        config[:ssl_ca_file].should eq('/custom/cert/ca-certificates')
        config[:ssl_ca_path].should eq('/custom/cert/')
      end
      Bosh::Registry.configure(@config)
    end

  end

end