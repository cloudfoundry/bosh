# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Registry do

  describe "configuring registry" do

    it "validates configuration file" do
      expect {
        Bosh::Registry.configure("foobar")
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid config format/)

      config = valid_config.merge("http" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /HTTP configuration is missing/)

      config = valid_config.merge("db" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Database configuration is missing/)

      config = valid_config.merge("cloud" => nil)

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Cloud configuration is missing/)

      config = valid_config
      config["cloud"]["plugin"] = nil

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Cloud plugin is missing/)

      config = valid_config

      expect {
        Bosh::Registry.configure(config)
      }.to raise_error(Bosh::Registry::ConfigError, /Could not find Provider Plugin/)
    end

    it "reads provided configuration file and sets singletons fo AWS" do
      config = valid_config
      config["cloud"] = {
        "plugin" => "aws",
        "aws" => {
          "access_key_id" => "foo",
          "secret_access_key" => "bar",
          "region" => "foobar",
          "max_retries" => 5
        }
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Bosh::Registry.http_port.should == 25777
      Bosh::Registry.http_user.should == "admin"
      Bosh::Registry.http_password.should == "admin"

      db = Bosh::Registry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == "/:memory:"
      db.opts[:max_connections].should == 433
      db.opts[:pool_timeout].should == 227

      im = Bosh::Registry.instance_manager
      im.should be_kind_of(Bosh::Registry::InstanceManager::Aws)
    end

    it "reads provided configuration file and sets singletons for OpenStack" do
      Fog::Compute.stub(:new)

      config = valid_config
      config["cloud"] = {
        "plugin" => "openstack",
        "openstack" => {
          "auth_url" => "http://127.0.0.1:5000/v2.0/tokens",
          "username" => "foo",
          "api_key" => "bar",
          "tenant" => "foo",
          "region" => ""
        }
      }
      Bosh::Registry.configure(config)

      logger = Bosh::Registry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Bosh::Registry.http_port.should == 25777
      Bosh::Registry.http_user.should == "admin"
      Bosh::Registry.http_password.should == "admin"

      db = Bosh::Registry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == "/:memory:"
      db.opts[:max_connections].should == 433
      db.opts[:pool_timeout].should == 227

      im = Bosh::Registry.instance_manager
      im.should be_kind_of(Bosh::Registry::InstanceManager::Openstack)
    end

  end

end