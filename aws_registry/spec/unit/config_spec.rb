# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsRegistry do

  describe "configuring AWS registry" do
    it "reads provided configuration file and sets singletons" do
      Bosh::AwsRegistry.configure(valid_config)

      logger = Bosh::AwsRegistry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Bosh::AwsRegistry.http_port.should == 25777
      Bosh::AwsRegistry.http_user.should == "admin"
      Bosh::AwsRegistry.http_password.should == "admin"

      db = Bosh::AwsRegistry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == "/:memory:"
      db.opts[:max_connections].should == 433
      db.opts[:pool_timeout].should == 227
    end

    it "validates configuration file" do
      expect {
        Bosh::AwsRegistry.configure("foobar")
      }.to raise_error(Bosh::AwsRegistry::ConfigError,
                       /Invalid config format/)

      config = valid_config.merge("http" => nil)

      expect {
        Bosh::AwsRegistry.configure(config)
      }.to raise_error(Bosh::AwsRegistry::ConfigError,
                       /HTTP configuration is missing/)

      config = valid_config.merge("db" => nil)

      expect {
        Bosh::AwsRegistry.configure(config)
      }.to raise_error(Bosh::AwsRegistry::ConfigError,
                       /Database configuration is missing/)

      config = valid_config.merge("aws" => nil)

      expect {
        Bosh::AwsRegistry.configure(config)
      }.to raise_error(Bosh::AwsRegistry::ConfigError,
                       /AWS configuration is missing/)
    end

  end
end
