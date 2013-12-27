require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'tmpdir'
require 'cloud/aws'

MOCK_AWS_ACCESS_KEY_ID = 'foo'
MOCK_AWS_SECRET_ACCESS_KEY = 'bar'

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
    'aws' => {
      'access_key_id' => MOCK_AWS_ACCESS_KEY_ID,
      'secret_access_key' => MOCK_AWS_SECRET_ACCESS_KEY,
      'region' => 'us-east-1',
      'default_key_name' => 'sesame',
      'default_security_groups' => []
    },
    'registry' => {
      'endpoint' => 'localhost:42288',
      'user' => 'admin',
      'password' => 'admin'
    },
    'agent' => {
      'foo' => 'bar',
      'baz' => 'zaz'
    }
  }
end

def make_cloud(options = nil)
  Bosh::AwsCloud::Cloud.new(options || mock_cloud_options)
end

def mock_registry(endpoint = 'http://registry:3333')
  registry = double('registry', :endpoint => endpoint)
  Bosh::Registry::Client.stub(:new).and_return(registry)
  registry
end

def mock_cloud(options = nil)
  ec2, region = mock_ec2
  AWS::EC2.stub(:new).and_return(ec2)

  yield ec2, region if block_given?

  Bosh::AwsCloud::Cloud.new(options || mock_cloud_options)
end

def mock_ec2
  region = double(AWS::EC2::Region)
  ec2 = double(AWS::EC2,
               :instances => double(AWS::EC2::InstanceCollection),
               :volumes => double(AWS::EC2::VolumeCollection),
               :images => double(AWS::EC2::ImageCollection),
               :regions => double(AWS::EC2::RegionCollection, :[] => region))

  yield ec2, region if block_given?

  return ec2, region
end

def dynamic_network_spec
  {
      'type' => 'dynamic',
      'cloud_properties' => {
          'security_groups' => %w[default]
      }
  }
end

def vip_network_spec
  {
    'type' => 'vip',
    'ip' => '10.0.0.1',
    'cloud_properties' => {}
  }
end

def combined_network_spec
  {
    'network_a' => dynamic_network_spec,
    'network_b' => vip_network_spec
  }
end

def resource_pool_spec
  {
    'key_name' => 'test_key',
    'availability_zone' => 'foobar-1a',
    'instance_type' => 'm3.zb'
  }
end

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
end

RSpec.configure do |config|
  config.before(:each) do
    logger = double('evil global stub in spec_helper').as_null_object
    Bosh::Clouds::Config.stub(:logger).and_return(logger)
  end
end
