# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Registry::InstanceManager do

  describe "configuring CloudStack registry" do

    before(:each) do
      @config = valid_config
      @config["cloud"] = {
        "plugin" => "cloudstack",
        "cloudstack" => {
          "endpoint" => "http://127.0.0.1:5000/client",
          "api_key" => "foo",
          "secret_access_key" => "bar",
         }
      }
    end

    it "validates presence of cloudstack cloud option" do
      @config["cloud"].delete("cloudstack")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid CloudStack configuration parameters/)
    end

    it "validates cloudstack cloud option is a Hash" do
      @config["cloud"]["cloudstack"] = "foobar"
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid CloudStack configuration parameters/)
    end

    it "validates presence of endpoint cloud option" do
      @config["cloud"]["cloudstack"].delete("endpoint")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid CloudStack configuration parameters/)
    end

    it "validates presence of api_key cloud option" do
      @config["cloud"]["cloudstack"].delete("api_key")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid CloudStack configuration parameters/)
    end

    it "validates presence of secret_access_key cloud option" do
      @config["cloud"]["cloudstack"].delete("secret_access_key")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid CloudStack configuration parameters/)
    end

  end

end
