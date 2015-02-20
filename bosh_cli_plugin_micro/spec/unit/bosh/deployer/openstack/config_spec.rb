require 'spec_helper'
require 'fog'

describe Bosh::Deployer::Config do
  before { @dir = Dir.mktmpdir('bdc_spec') }
  after { FileUtils.remove_entry_secure @dir }

  it 'should default agent properties' do
    config = Psych.load_file(spec_asset('test-bootstrap-config-openstack.yml'))
    config['dir'] = @dir
    Bosh::Deployer::Config.configure(config)

    properties = Bosh::Deployer::Config.cloud_options['properties']
    expect(properties['agent']).to be_kind_of(Hash)
    expect(properties['agent']['mbus'].start_with?('https://')).to be(true)
    expect(properties['agent']['blobstore']).to be_kind_of(Hash)
  end

  it 'should map network properties' do
    config = Psych.load_file(spec_asset('test-bootstrap-config-openstack.yml'))
    config['dir'] = @dir
    Bosh::Deployer::Config.configure(config)

    networks = Bosh::Deployer::Config.networks
    expect(networks).to be_kind_of(Hash)

    net = networks['bosh']
    expect(net).to be_kind_of(Hash)
    %w(cloud_properties type).each do |key|
      expect(net[key]).not_to be_nil
    end
  end

  it 'should default vm env properties' do
    env = Bosh::Deployer::Config.env
    expect(env).to be_kind_of(Hash)
    expect(env).to have_key('bosh')
    expect(env['bosh']).to be_kind_of(Hash)
    expect(env['bosh']['password']).not_to be_nil
    expect(env['bosh']['password']).to be_kind_of(String)
    expect(env['bosh']['password']).to eq('$6$salt$password')
  end

  it 'should contain default vm resource properties' do
    Bosh::Deployer::Config.configure('dir' => @dir, 'cloud' => { 'plugin' => 'openstack' })
    resources = Bosh::Deployer::Config.resources
    expect(resources).to be_kind_of(Hash)

    expect(resources['persistent_disk']).to be_kind_of(Integer)

    cloud_properties = resources['cloud_properties']
    expect(cloud_properties).to be_kind_of(Hash)

    ['instance_type'].each do |key|
      expect(cloud_properties[key]).not_to be_nil
    end
  end

  it 'should have openstack and registry object access' do
    config = Psych.load_file(spec_asset('test-bootstrap-config-openstack.yml'))
    config['dir'] = @dir
    Bosh::Deployer::Config.configure(config)
    openstack = double(Fog::Compute)
    allow(Fog::Compute).to receive(:new).and_return(openstack)
    glance = double(Fog::Image)
    allow(Fog::Image).to receive(:new).and_return(glance)
    volume = double(Fog::Volume)
    allow(Fog::Volume).to receive(:new).and_return(volume)
    cloud = Bosh::Deployer::Config.cloud
    expect(cloud.respond_to?(:openstack)).to be(true)
    expect(cloud.respond_to?(:registry)).to be(true)
    expect(cloud.registry).to be_kind_of(Bosh::Registry::Client)
  end
end
