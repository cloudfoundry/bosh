# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.
require 'rspec'
require 'tmpdir'
require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

require 'cloud/cloudstack'

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
    'cloudstack' => {
      'endpoint' => 'http://127.0.0.1:5000',
      'api_key' => 'admin',
      'secret_access_key' => 'foobar',
      'default_zone' => 'foobar-1a',
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
  Bosh::CloudStackCloud::Cloud.new(options || mock_cloud_options)
end

def mock_registry(endpoint = 'http://registry:3333')
  registry = mock('registry', :endpoint => endpoint)
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
  zones = [double('foobar-1a', :name => mock_cloud_options['cloudstack']['default_zone'], :id => 'foobar-1a', :network_type => 'Basic')]
  disk_offerings = [double('disk_offer1', :name => 'disk_offer-10000', :id => 'disk_offer1', :disk_size => 10000)]
  networks = double('networks')
  jobs = double('jobs')

  compute = double(Fog::Compute)

  compute.stub(:servers).and_return(servers)
  compute.stub(:images).and_return(images)
  compute.stub(:flavors).and_return(flavors)
  compute.stub(:volumes).and_return(volumes)
  compute.stub(:addresses).and_return(addresses)
  compute.stub(:snapshots).and_return(snapshots)
  compute.stub(:key_pairs).and_return(key_pairs)
  compute.stub(:security_groups).and_return(security_groups)
  compute.stub(:zones).and_return(zones)
  compute.stub(:disk_offerings).and_return(disk_offerings)
  compute.stub(:networks).and_return(networks)
  compute.stub(:jobs).and_return(jobs)

  Fog::Compute.stub(:new).and_return(compute)

  yield compute if block_given?

  Bosh::CloudStackCloud::Cloud.new(options || mock_cloud_options)
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

def generate_job
  double("job", :id => SecureRandom.uuid)
end

RSpec.configure do |config|
  config.before(:each) { Bosh::Clouds::Config.stub(:logger).and_return(double.as_null_object)  }
end
