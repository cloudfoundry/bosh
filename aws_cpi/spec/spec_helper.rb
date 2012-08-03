# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "tmpdir"

require "cloud/aws"

class AwsConfig
  attr_accessor :db, :logger, :uuid
end

aws_config = AwsConfig.new
aws_config.db = nil # AWS CPI doesn't need DB
aws_config.logger = Logger.new(StringIO.new)
aws_config.logger.level = Logger::DEBUG

Bosh::Clouds::Config.configure(aws_config)

MOCK_AWS_ACCESS_KEY_ID = "foo"
MOCK_AWS_SECRET_ACCESS_KEY = "bar"

def internal_to(*args, &block)
  example = describe *args, &block
  klass = args[0]
  if klass.is_a? Class
    saved_private_instance_methods = klass.private_instance_methods
    example.before do
      klass.class_eval { public *saved_private_instance_methods }
    end
    example.after do
      klass.class_eval { private *saved_private_instance_methods }
    end
  end
end

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
    },
    "agent" => {
      "foo" => "bar",
      "baz" => "zaz"
    }
  }
end

def make_cloud(options = nil)
  Bosh::AwsCloud::Cloud.new(options || mock_cloud_options)
end

def mock_registry(endpoint = "http://registry:3333")
  registry = mock("registry", :endpoint => endpoint)
  Bosh::AwsCloud::RegistryClient.stub!(:new).and_return(registry)
  registry
end

def mock_cloud(options = nil)
  instances = double("instances")
  volumes = double("volumes")
  images = double("images")

  ec2 = double(AWS::EC2)

  ec2.stub(:instances).and_return(instances)
  ec2.stub(:volumes).and_return(volumes)
  ec2.stub(:images).and_return(images)

  AWS::EC2.stub(:new).and_return(ec2)

  yield ec2 if block_given?

  Bosh::AwsCloud::Cloud.new(options || mock_cloud_options)
end

def dynamic_network_spec
  {
      "type" => "dynamic",
      "cloud_properties" => {
          "security_groups" => %w[default]
      }
  }
end

def vip_network_spec
  {
    "type" => "vip",
    "ip" => "10.0.0.1"
  }
end

def combined_network_spec
  {
    "network_a" => dynamic_network_spec,
    "network_b" => vip_network_spec
  }
end

def resource_pool_spec
  {
    "key_name" => "test_key",
    "availability_zone" => "foobar-1a",
    "instance_type" => "m3.zb"
  }
end


