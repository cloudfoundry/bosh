# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'
require 'json'

describe Bosh::Registry::InstanceManager do
  let(:connection_options) { nil }
  let(:config) {
    valid_config.merge({'cloud' => {
      'plugin' => 'openstack',
      'openstack' => {
        'auth_url' => 'http://127.0.0.1:5000/v3.0',
        'username' => 'foo',
        'api_key' => 'bar',
        'tenant' => 'foo',
        'domain' => 'mydomain',
        'region' => '',
        'connection_options' => connection_options,
      }
    }})
  }
  let(:manager) do
    Bosh::Registry.configure(config)
    Bosh::Registry.instance_manager
  end
  let(:compute) { double('Fog::Compute') }

  def create_instance(params)
    Bosh::Registry::Models::RegistryInstance.create(params)
  end

  def actual_ip_is(private_ip, floating_ip)
    servers = double('servers')
    instance = double('instance')

    expect(compute).to receive(:servers).and_return(servers)
    expect(servers).to receive(:find).and_return(instance)
    expect(instance).to receive(:private_ip_addresses).and_return([private_ip])
    expect(instance).to receive(:floating_ip_addresses).and_return([floating_ip])
  end

  describe :openstack do
    let(:openstack_compute) {
      {
        :provider => 'OpenStack',
        :openstack_auth_url => 'http://127.0.0.1:5000/v3.0/tokens',
        :openstack_username => 'foo',
        :openstack_api_key => 'bar',
        :openstack_tenant => 'foo',
        :openstack_domain_name => 'mydomain',
        :openstack_region => '',
        :openstack_endpoint_type => nil,
        :connection_options => connection_options,
      }
    }

    it 'should create a Fog::Compute connection' do
      expect(Fog::Compute).to receive(:new).with(openstack_compute).and_return(compute)
      expect(manager.openstack).to eql(compute)
    end

    context 'with connection options' do
      let(:connection_options) {
        JSON.generate({
          'ssl_verify_peer' => false,
        })
      }

      it 'should add optional options to the Fog::Compute connection' do
        expect(Fog::Compute).to receive(:new).with(openstack_compute).and_return(compute)
        expect(manager.openstack).to eql(compute)
      end
    end
  end

  describe 'reading settings' do
    before(:each) do
      allow(Fog::Compute).to receive(:new).and_return(compute)
    end

    it 'returns settings after verifying IP address' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      actual_ip_is('10.0.0.1', nil)
      expect(manager.read_settings('foo', '10.0.0.1')).to eq('bar')
    end

    it 'returns settings after verifying floating IP address' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      actual_ip_is(nil, '10.0.1.1')
      expect(manager.read_settings('foo', '10.0.1.1')).to eq('bar')
    end

    it 'raises an error if IP cannot be verified' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      actual_ip_is('10.0.0.1', '10.0.1.1')
      expect {
        manager.read_settings('foo', '10.0.2.1')
      }.to raise_error(Bosh::Registry::InstanceError,
                       "Instance IP mismatch, expected IP is `10.0.2.1', " \
                       "actual IP(s): `10.0.0.1, 10.0.1.1'")
    end

    it 'it should create a new fog connection if there is an Unauthorized error' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      expect(compute).to receive(:servers).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      actual_ip_is('10.0.0.1', nil)
      expect(manager.read_settings('foo', '10.0.0.1')).to eq('bar')
    end

    it 'it should raise a ConnectionError if there is a persistent Unauthorized error' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      expect(compute).to receive(:servers).twice.and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      expect {
        expect(manager.read_settings('foo', '10.0.0.1')).to eq('bar')
      }.to raise_error(Bosh::Registry::ConnectionError, 'Unable to connect to OpenStack API: Unauthorized') 
    end
  end
end
