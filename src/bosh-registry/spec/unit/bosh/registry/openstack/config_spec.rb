require "spec_helper"

describe Bosh::Registry::InstanceManager do

  describe "configuring OpenStack registry" do

    before(:each) do
      @config = valid_config
      @config["cloud"] = {
        "plugin" => "openstack",
        "openstack" => {
          "auth_url" => "http://127.0.0.1:5000/v2.0",
          "username" => "foo",
          "api_key" => "bar",
          "tenant" => "foo",
          "region" => ""
        }
      }
    end

    it "validates presence of openstack cloud option" do
      @config["cloud"].delete("openstack")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

    it "validates openstack cloud option is a Hash" do
      @config["cloud"]["openstack"] = "foobar"
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

    it "validates presence of auth_url cloud option" do
      @config["cloud"]["openstack"].delete("auth_url")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

    it "validates presence of username cloud option" do
      @config["cloud"]["openstack"].delete("username")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

    it "validates presence of api_key cloud option" do
      @config["cloud"]["openstack"].delete("api_key")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

    it "validates presence of tenant cloud option" do
      @config["cloud"]["openstack"].delete("tenant")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid OpenStack configuration parameters/)
    end

  end

end