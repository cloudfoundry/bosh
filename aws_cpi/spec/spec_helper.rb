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
    }
  }
end

def make_cloud(options = nil)
  Bosh::AWSCloud::Cloud.new(options || mock_cloud_options)
end

def make_mock_cloud(options = nil)
  instances = double("instances")

  ec2 = double(AWS::EC2)
  ec2.stub(:instances).and_return(instances)
  AWS::EC2.stub(:new).and_return(ec2)

  yield ec2 if block_given?

  Bosh::AWSCloud::Cloud.new(options || mock_cloud_options)
end

def with_warnings(flag)
  old_verbose, $VERBOSE = $VERBOSE, flag
  yield
ensure
  $VERBOSE = old_verbose
end

def constantize(string)
  string.split('::').inject(Object) do |memo, name|
    memo = memo.const_get(name)
    memo
  end
end

def parse_constant(constant)
  source, _, constant_name = constant.to_s.rpartition('::')
  [constantize(source), constant_name]
end

def with_constants(constants, &block)
  saved_constants = {}
  constants.each do |constant, val|
    source_object, const_name = parse_constant(constant)

    saved_constants[constant] = source_object.const_get(const_name)
    with_warnings(nil) { source_object.const_set(const_name, val) }
  end

  begin
    block.call
  ensure
    constants.each do |constant, val|
      source_object, const_name = parse_constant(constant)

      with_warnings(nil) do
        source_object.const_set(const_name, saved_constants[constant])
      end
    end
  end
end
