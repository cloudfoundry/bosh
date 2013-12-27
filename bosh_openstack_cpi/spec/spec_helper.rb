# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'tmpdir'
require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

require 'cloud/openstack'

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
    'openstack' => {
      'auth_url' => 'http://127.0.0.1:5000/v2.0',
      'username' => 'admin',
      'api_key' => 'nova',
      'tenant' => 'admin',
      'region' => 'RegionOne',
      'state_timeout' => 0.1
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
  Bosh::OpenStackCloud::Cloud.new(options || mock_cloud_options)
end

def mock_registry(endpoint = 'http://registry:3333')
  registry = double('registry', :endpoint => endpoint)
  Bosh::Registry::Client.stub(:new).and_return(registry)
  registry
end

def mock_cloud(options = nil)
  servers = double('servers')
  images = double('images')
  flavors = double('flavors')
  volumes = double('volumes')
  addresses = double('addresses')
  snapshots = double('snapshots')
  key_pairs = double('key_pairs')
  security_groups = double('security_groups')

  glance = double(Fog::Image)
  Fog::Image.stub(:new).and_return(glance)

  openstack = double(Fog::Compute)

  openstack.stub(:servers).and_return(servers)
  openstack.stub(:images).and_return(images)
  openstack.stub(:flavors).and_return(flavors)
  openstack.stub(:volumes).and_return(volumes)
  openstack.stub(:addresses).and_return(addresses)
  openstack.stub(:snapshots).and_return(snapshots)
  openstack.stub(:key_pairs).and_return(key_pairs)
  openstack.stub(:security_groups).and_return(security_groups)

  Fog::Compute.stub(:new).and_return(openstack)

  yield openstack if block_given?

  Bosh::OpenStackCloud::Cloud.new(options || mock_cloud_options)
end

def mock_glance(options = nil)
  images = double('images')

  openstack = double(Fog::Compute)
  Fog::Compute.stub(:new).and_return(openstack)

  glance = double(Fog::Image)
  glance.stub(:images).and_return(images)

  Fog::Image.stub(:new).and_return(glance)

  yield glance if block_given?

  Bosh::OpenStackCloud::Cloud.new(options || mock_cloud_options)
end

def dynamic_network_spec
  {
    'type' => 'dynamic',
    'cloud_properties' => {
      'security_groups' => %w[default]
    }
  }
end

def manual_network_spec
  {
    'type' => 'manual',
    'cloud_properties' => {
      'security_groups' => %w[default],
      'net_id' => 'net'
    }
  }
end

def vip_network_spec
  {
    'type' => 'vip',
    'ip' => '10.0.0.1'
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
    'instance_type' => 'm1.tiny'
  }
end

RSpec.configure do |config|
  config.before(:each) { Bosh::Clouds::Config.stub(:logger).and_return(double.as_null_object)  }
end
