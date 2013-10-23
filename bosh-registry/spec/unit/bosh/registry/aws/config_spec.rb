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

  end

end