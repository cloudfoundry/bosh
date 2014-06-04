require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  describe :new do
    let(:cloud_options) { mock_cloud_options }
    let(:openstack_parms) {
      {
        :provider => 'OpenStack',
        :openstack_auth_url => 'http://127.0.0.1:5000/v2.0/tokens',
        :openstack_username => 'admin',
        :openstack_api_key => 'nova',
        :openstack_tenant => 'admin',
        :openstack_region => 'RegionOne',
        :openstack_endpoint_type => nil,
        :connection_options => connection_options,
      }
    }
    let(:volume_parms) {
      {
        :provider => 'OpenStack',
        :openstack_auth_url => 'http://127.0.0.1:5000/v2.0/tokens',
        :openstack_username => 'admin',
        :openstack_api_key => 'nova',
        :openstack_tenant => 'admin',
        :openstack_endpoint_type => nil,
        :connection_options => connection_options,
      }
    }
    let(:connection_options) { nil }
    let(:compute) { instance_double('Fog::Compute') }
    let(:image) { instance_double('Fog::Image') }
    let(:volume) { instance_double('Fog::Volume') }

    it 'should create a Fog connection' do
      allow(Fog::Compute).to receive(:new).and_return(compute)
      allow(Fog::Image).to receive(:new).and_return(image)
      allow(Fog::Volume).to receive(:new).and_return(volume)
      cloud = Bosh::OpenStackCloud::Cloud.new(mock_cloud_options['properties'])

      expect(cloud.openstack).to eql(compute)
      expect(cloud.glance).to eql(image)
      expect(cloud.volume).to eql(volume)
    end

    it 'raises ArgumentError on initializing with blank options' do
      options = Hash.new('options')
      expect {
        Bosh::OpenStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end

    it 'raises ArgumentError on initializing with non Hash options' do
      options = 'this is a string'
      expect {
        Bosh::OpenStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end

    it 'raises a CloudError exception if cannot connect to the OpenStack Compute API' do
      allow(Fog::Compute).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      allow(Fog::Image).to receive(:new)
      allow(Fog::Volume).to receive(:new)
      expect {
        Bosh::OpenStackCloud::Cloud.new(mock_cloud_options['properties'])
      }.to raise_error(Bosh::Clouds::CloudError,
        'Unable to connect to the OpenStack Compute API. Check task debug log for details.')
    end

    it 'raises a CloudError exception if cannot connect to the OpenStack Image Service API' do
      allow(Fog::Compute).to receive(:new)
      allow(Fog::Image).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      allow(Fog::Volume).to receive(:new)
      expect {
        Bosh::OpenStackCloud::Cloud.new(mock_cloud_options['properties'])
      }.to raise_error(Bosh::Clouds::CloudError,
        'Unable to connect to the OpenStack Image Service API. Check task debug log for details.')
    end

    it 'raises a CloudError exception if cannot connect to the OpenStack Volume Service API' do
      allow(Fog::Compute).to receive(:new)
      allow(Fog::Image).to receive(:new)
      allow(Fog::Volume).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      expect {
        Bosh::OpenStackCloud::Cloud.new(mock_cloud_options['properties'])
      }.to raise_error(Bosh::Clouds::CloudError,
        'Unable to connect to the OpenStack Volume API. Check task debug log for details.')
    end

    context 'with connection options' do
      let(:connection_options) {
        JSON.generate({
          'ssl_verify_peer' => false,
        })
      }

      it 'should add optional options to the Fog connection' do
        cloud_options['properties']['openstack']['connection_options'] = connection_options
        allow(Fog::Compute).to receive(:new).and_return(compute)
        allow(Fog::Image).to receive(:new).with(openstack_parms).and_return(image)
        allow(Fog::Volume).to receive(:new).and_return(volume)
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])

        expect(Fog::Compute).to have_received(:new).with(hash_including(connection_options: connection_options))
      end
    end
  end
end
