# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"

require "cloud/aws"

class AWSConfig
  attr_accessor :db, :logger, :uuid
end

aws_config = AWSConfig.new
aws_config.db = nil # AWS CPI doesn't need DB
aws_config.logger = Logger.new(STDOUT)
aws_config.logger.level = Logger::DEBUG

Bosh::Clouds::Config.configure(aws_config)

MOCK_AWS_ACCESS_KEY_ID = "foo"
MOCK_AWS_SECRET_ACCESS_KEY = "bar"

def mock_cloud_options
  {
    "aws" => {
      "access_key_id" => MOCK_AWS_ACCESS_KEY_ID,
      "secret_access_key" => MOCK_AWS_SECRET_ACCESS_KEY
    },
    "registry" => {
      "endpoint" => "localhost:42288",
      "user" => "admin",
      "password" => "admin"
    }
  }
end

def make_cloud(options = nil)
  Bosh::AWSCloud::Cloud.new(options || mock_cloud_options)
end
