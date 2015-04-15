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

      before { allow(VCloudSdk::Client).to receive(:new).with('fake-url', 'user@fake-org', 'password', {}, logger).and_return(client) }
      let(:client) { instance_double('VCloudSdk::Client', catalog_exists?: false) }

      before { allow(client).to receive(:find_vdc_by_name).with('fake-vdc').and_return(vdc) }
      let(:vdc) { instance_double('VCloudSdk::VDC', find_vapp_by_name: vapp) }
      let(:entity_xml) {double('entity_xml', remove_link: 'thehref')}
      let(:vapp) { instance_double('VCloudSdk::VApp', power_off: nil, delete: nil, vms: [], status: 'POWERED_ON', entity_xml: entity_xml) }
      let(:vm1) { instance_double('VCloudSdk::VM') }
      let(:vm2) { instance_double('VCloudSdk::VM') }
      let(:disk) { instance_double('VCloudSdk::Disk', name: 'fake-disk-name') }
      let(:catalog) { instance_double('VCloudSdk::Catalog') }

      before { allow(manifest).to receive(:to_h).and_return(config) }
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

      context 'when vapp exists' do
        it 'powers off vapp, deletes independent disks and deletes the vapp' do
          expect(vdc).to receive(:find_vapp_by_name).with('vapp-name').and_return(vapp)

          expect(vapp).to receive(:power_off).once.ordered
          expect(vapp).to receive(:vms).once.ordered.and_return([vm1, vm2])
          expect(vm1).to receive(:independent_disks).once.ordered.and_return([disk])
          expect(vm1).to receive(:detach_disk).with(disk).once.ordered
          expect(vdc).to receive(:delete_all_disks_by_name).with('fake-disk-name').once.ordered
          expect(vm2).to receive(:independent_disks).once.ordered.and_return([])
          expect(vapp).to receive(:delete).once.ordered

          subject.clean
        end

        context 'when app is powered off' do
          before do
            allow(vapp).to receive(:status).and_return('POWERED_OFF')
          end

          it 'does not power off' do
            expect(vapp).to_not receive(:power_off)
            subject.clean
          end
        end
      end

      context 'when vapp does not exist' do
        it 'does not delete anything' do
          expect(vdc).to receive(:find_vapp_by_name).with('vapp-name').and_raise(VCloudSdk::ObjectNotFoundError)
          expect(logger).to receive(:info).
            with('No vapp was deleted during clean up. Details: #<VCloudSdk::ObjectNotFoundError: VCloudSdk::ObjectNotFoundError>')
          subject.clean
        end
      end

      context 'when catalog exists' do
        it 'deletes the vapp catalog and media catalog' do
          expect(client).to receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(true)
          expect(client).to receive(:find_catalog_by_name).with('vapp-catalog').ordered.and_return(catalog)
          expect(catalog).to receive(:delete_all_items).ordered

          expect(client).to receive(:catalog_exists?).with('media-catalog').ordered.and_return(true)
          expect(client).to receive(:find_catalog_by_name).with('media-catalog').ordered.and_return(catalog)
          expect(catalog).to receive(:delete_all_items).ordered

          subject.clean
        end
      end

      context 'when one catalog does not exist' do
        it 'deletes the media catalog only' do
          expect(client).to receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(false)
          expect(client).not_to receive(:find_catalog_by_name).with('vapp-catalog')

          expect(client).to receive(:catalog_exists?).with('media-catalog').ordered.and_return(true)
          expect(client).to receive(:find_catalog_by_name).with('media-catalog').ordered.and_return(catalog)
          expect(catalog).to receive(:delete_all_items).ordered

          subject.clean
        end

        it 'deletes the vapp catalog only' do
          expect(client).to receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(true)
          expect(client).to receive(:find_catalog_by_name).with('vapp-catalog').ordered.and_return(catalog)
          expect(catalog).to receive(:delete_all_items).ordered

          expect(client).to receive(:catalog_exists?).with('media-catalog').ordered.and_return(false)
          expect(client).not_to receive(:find_catalog_by_name).with('media-catalog')

          subject.clean
        end
      end

      context 'when neither vapp nor media catalog exists' do
        it 'deletes the media catalog only' do
          expect(client).to receive(:catalog_exists?).with('vapp-catalog').ordered.and_return(false)
          expect(client).not_to receive(:find_catalog_by_name).with('vapp-catalog')

          expect(client).to receive(:catalog_exists?).with('media-catalog').ordered.and_return(false)
          expect(client).not_to receive(:find_catalog_by_name).with('media-catalog')

          subject.clean
        end
      end
    end
  end
end
