# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenstackRegistry do

  describe "configuring OpenStack registry" do
    it "reads provided configuration file and sets singletons" do
      Bosh::OpenstackRegistry.configure(valid_config)

      logger = Bosh::OpenstackRegistry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Bosh::OpenstackRegistry.http_port.should == 25777
      Bosh::OpenstackRegistry.http_user.should == "admin"
      Bosh::OpenstackRegistry.http_password.should == "admin"

      db = Bosh::OpenstackRegistry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == "/:memory:"
      db.opts[:max_connections].should == 433
      db.opts[:pool_timeout].should == 227
    end

    it "validates configuration file" do
      expect {
        Bosh::OpenstackRegistry.configure("foobar")
      }.to raise_error(Bosh::OpenstackRegistry::ConfigError,
                       /Invalid config format/)

      config = valid_config.merge("http" => nil)

      expect {
        Bosh::OpenstackRegistry.configure(config)
      }.to raise_error(Bosh::OpenstackRegistry::ConfigError,
                       /HTTP configuration is missing/)

      config = valid_config.merge("db" => nil)

      expect {
        Bosh::OpenstackRegistry.configure(config)
      }.to raise_error(Bosh::OpenstackRegistry::ConfigError,
                       /Database configuration is missing/)

      config = valid_config.merge("openstack" => nil)

      expect {
        Bosh::OpenstackRegistry.configure(config)
      }.to raise_error(Bosh::OpenstackRegistry::ConfigError,
                       /OpenStack configuration is missing/)
    end

  end
end
