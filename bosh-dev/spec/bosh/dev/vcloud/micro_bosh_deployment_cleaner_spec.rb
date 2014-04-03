require 'spec_helper'
require 'bosh/dev/vcloud/micro_bosh_deployment_cleaner'
require 'bosh/dev/vcloud/micro_bosh_deployment_manifest'

module Bosh::Dev::VCloud
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      subject(:cleaner) { described_class.new(env, manifest) }
      let(:manifest) { instance_double('Bosh::Dev::VCloud::MicroBoshDeploymentManifest') }
      let(:env) do
        {
          'BOSH_VCLOUD_VAPP_NAME' => 'vapp-name',
          'BOSH_VCLOUD_VAPP_CATALOG' => 'vapp-catalog',
          'BOSH_VCLOUD_MEDIA_CATALOG' => 'media-catalog'
        }
      end

      before { VCloudSdk::Client.stub(:new).with('fake-url', 'user@fake-org', 'password', {}, logger).and_return(client) }
      let(:client) { instance_double('VCloudSdk::Client', catalog_exists?: false) }

      before { client.stub(:find_vdc_by_name).with('fake-vdc').and_return(vdc) }
      let(:vdc) { instance_double('VCloudSdk::VDC', find_vapp_by_name: vapp) }
      let(:vapp) { instance_double('VCloudSdk::VApp', power_off: nil, delete: nil, vms: []) }
      let(:vm1) { instance_double('VCloudSdk::VM') }
      let(:vm2) { instance_double('VCloudSdk::VM') }
      let(:disk) { instance_double('VCloudSdk::Disk') }
      let(:catalog) { instance_double('VCloudSdk::Catalog') }

      before { manifest.stub(:to_h).and_return(config) }
      let(:config) do
        { 'cloud' => {
            'properties' => {
              'vcds' => [{
                'url' => 'fake-url',
                'user' => 'user',
                'password' => 'password',
                'entities' => {
                  'organization' => 'fake-org',
                  'virtual_datacenter' => 'fake-vdc'
                }
              }]
            }
        } }
      end

      before { Logger.stub(new: logger) }
      let(:logger) { instance_double('Logger', info: nil) }

      context 'when vapp exists' do
        it 'powers off vapp, deletes independent disks and deletes the vapp' do
          vdc.should_receive(:find_vapp_by_name).with('vapp-name').and_return(vapp)

          vapp.should_receive(:power_off).once.ordered
          vapp.should_receive(:vms).once.ordered.and_return([vm1, vm2])
          vm1.should_receive(:independent_disks).once.ordered.and_return([disk])
          vm1.should_receive(:detach_disk).with(disk).once.ordered
          disk.should_receive(:delete).once.ordered
          vm2.should_receive(:independent_disks).once.ordered.and_return([])
          vapp.should_receive(:delete).once.ordered

          subject.clean
        end
      end

      context 'when vapp does not exist' do
        it 'does not delete anything' do
          vdc.should_receive(:find_vapp_by_name).with('vapp-name').and_raise(VCloudSdk::ObjectNotFoundError)
          logger.should_receive(:info).with('No vapp was deleted during clean up. Details: #<VCloudSdk::ObjectNotFoundError: VCloudSdk::ObjectNotFoundError>')

          subject.clean
        end
      end

      context 'when catalog exists' do
        it 'deletes the vapp catalog and media catalog' do
          client.should_receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(true)
          client.should_receive(:find_catalog_by_name).with('vapp-catalog').ordered.and_return(catalog)
          catalog.should_receive(:delete_all_items).ordered

          client.should_receive(:catalog_exists?).with('media-catalog').ordered.and_return(true)
          client.should_receive(:find_catalog_by_name).with('media-catalog').ordered.and_return(catalog)
          catalog.should_receive(:delete_all_items).ordered

          subject.clean
        end
      end

      context 'when one catalog does not exist' do
        it 'deletes the media catalog only' do
          client.should_receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(false)
          client.should_not_receive(:find_catalog_by_name).with('vapp-catalog')

          client.should_receive(:catalog_exists?).with('media-catalog').ordered.and_return(true)
          client.should_receive(:find_catalog_by_name).with('media-catalog').ordered.and_return(catalog)
          catalog.should_receive(:delete_all_items).ordered

          subject.clean
        end

        it 'deletes the vapp catalog only' do
          client.should_receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(true)
          client.should_receive(:find_catalog_by_name).with('vapp-catalog').ordered.and_return(catalog)
          catalog.should_receive(:delete_all_items).ordered

          client.should_receive(:catalog_exists?).with('media-catalog').ordered.and_return(false)
          client.should_not_receive(:find_catalog_by_name).with('media-catalog')

          subject.clean
        end
      end

      context 'when neither vapp nor media catalog exists' do
        it 'deletes the media catalog only' do
          client.should_receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(false)
          client.should_not_receive(:find_catalog_by_name).with('vapp-catalog')

          client.should_receive(:catalog_exists?).with('media-catalog').ordered.and_return(false)
          client.should_not_receive(:find_catalog_by_name).with('media-catalog')

          subject.clean
        end
      end
    end
  end
end
