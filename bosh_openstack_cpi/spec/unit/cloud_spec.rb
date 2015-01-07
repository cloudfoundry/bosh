require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:default_connection_options) {
    { "instrumentor" => Bosh::OpenStackCloud::ExconLoggingInstrumentor }
  }
  let(:options) do
    {
      'openstack' => {
        'auth_url' => 'fake-auth-url',
        'username' => 'fake-username',
        'api_key' => 'fake-api-key',
        'tenant' => 'fake-tenant'
      },
      'registry' => {
        'endpoint' => 'fake-registry',
        'user' => 'fake-user',
        'password' => 'fake-password',
      }
    }
  end

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
        :connection_options => merged_connection_options,
      }
    }
    let(:volume_parms) {
      {
        :provider => 'OpenStack',
        :openstack_auth_url => 'http://127.0.0.1:5000/v2.0/tokens',
        :openstack_username => 'admin',
        :openstack_api_key => 'nova',
        :openstack_tenant => 'admin',
        :openstack_region => 'RegionOne',
        :openstack_endpoint_type => nil,
        :connection_options => merged_connection_options,
      }
    }
    let(:connection_options) { nil }
    let(:merged_connection_options) { default_connection_options }

    let(:compute) { instance_double('Fog::Compute') }
    before { allow(Fog::Compute).to receive(:new).and_return(compute) }

    let(:image) { instance_double('Fog::Image') }
    before { allow(Fog::Image).to receive(:new).and_return(image) }

    let(:volume) { instance_double('Fog::Volume') }
    before { allow(Fog::Volume).to receive(:new).and_return(volume) }

    describe 'validation' do
      subject(:subject) { Bosh::OpenStackCloud::Cloud.new(options) }

      context 'when all required options are specified' do
        it 'does not raise an error' do
          expect { subject }.to_not raise_error
        end
      end

      context 'when connection_options are specified' do
        it 'expects connection_options to be a hash' do
          options['openstack']['connection_options'] = { 'any-key' => 'any-value' }

          expect { subject }.to_not raise_error
        end

        it 'raises an error if connection_options is not a Hash' do
          options['openstack']['connection_options'] = 'connection_options'

          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'when boot_from_volume is specified' do
        it 'expects boot_from_volume to be a boolean' do
          options['openstack']['boot_from_volume'] = true

          expect { subject }.to_not raise_error
        end

        it 'raises an error if boot_from_volume is not a boolean' do
          options['openstack']['boot_from_volume'] = 'boot_from_volume'

          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'config_drive' do
        it 'accepts cdrom as a value' do
          options['openstack']['config_drive'] = 'cdrom'
          expect { subject }.to_not raise_error
        end

        it 'accepts disk as a value' do
          options['openstack']['config_drive'] = 'disk'
          expect { subject }.to_not raise_error
        end

        it 'accepts nil as a value' do
          options['openstack']['config_drive'] = nil
          expect { subject }.to_not raise_error
        end

        it 'raises an error if config_drive is not cdrom or disk or nil' do
          options['openstack']['config_drive'] = 'incorrect-value'
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'when options are empty' do
        let(:options) { Hash.new('options') }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end

      context 'when options are not a Hash' do
        let(:options) { 'this is a string' }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /Invalid OpenStack cloud properties/)
        end
      end
    end

    it 'creates a Fog connection' do
      cloud = Bosh::OpenStackCloud::Cloud.new(mock_cloud_options['properties'])

      expect(cloud.openstack).to eql(compute)
      expect(cloud.glance).to eql(image)
      expect(cloud.volume).to eql(volume)
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
      let(:connection_options) { {'ssl_verify_peer' => false} }
      let(:merged_connection_options) {
        default_connection_options.merge(connection_options)
      }

      it 'should add optional options to the Fog connection' do
        cloud_options['properties']['openstack']['connection_options'] = connection_options
        allow(Fog::Compute).to receive(:new).and_return(compute)
        allow(Fog::Image).to receive(:new).and_return(image)
        allow(Fog::Volume).to receive(:new).and_return(volume)
        Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'])

        expect(Fog::Compute).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
        expect(Fog::Image).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
        expect(Fog::Volume).to have_received(:new).with(hash_including(connection_options: merged_connection_options))
      end
    end
  end

  describe 'detaching a disk' do
    subject(:cloud) { Bosh::OpenStackCloud::Cloud.new(options) }

    let(:compute_mock) { Fog::Compute.new({ :provider => 'OpenStack', :openstack_auth_url => 'url', :openstack_username => 'fake-username', :openstack_tenant => 'fake-tenant' }) }
    let(:server_id) { compute_mock.create_server('server1', 'img', 'flav')[:body]["server"]["id"] }
    let(:volume_id) { compute_mock.create_volume('disk1', 'desc', 1)[:body]["volume"]["id"] }
    let(:attachment_id) { compute_mock.attach_volume(volume_id, server_id, '/dev/sda')[:body]["volumeAttachment"]["id"] }

    before do
      Fog.mock!
      Bosh::Clouds::Config.configure(double('config', task_checkpoint: true))
    end

    after { Fog.unmock! }

    it 'sends the right magic to fog' do
      expect_any_instance_of(Fog::Compute::OpenStack::Mock).to receive(:detach_volume).with(server_id, attachment_id) do
        compute_mock.get_volume_details(volume_id)[:body]["volume"]["status"] = "available"
      end

      expect_any_instance_of(Bosh::Registry::Client).to receive(:read_settings).with('server1').and_return({
            'disks' => { 'persistent' => { volume_id => '/dev/sda', 'other' => '/dev/sdb' } } })

      expect_any_instance_of(Bosh::Registry::Client).to receive(:update_settings).with('server1', {
            'disks' => { 'persistent' => { 'other' => '/dev/sdb' } } })

      cloud.detach_disk(server_id, volume_id)
    end
  end
end
