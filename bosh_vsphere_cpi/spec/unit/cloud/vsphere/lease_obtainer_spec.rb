require 'spec_helper'
require 'cloud/vsphere/lease_obtainer'

module VSphereCloud
  describe LeaseObtainer do
    describe '#obtain' do
      subject(:lease_obtainer) { described_class.new(client, logger) }
      let(:client) { instance_double('VSphereCloud::Client') }
      let(:logger) { Logger.new('/dev/null') }

      let(:resource_pool) { instance_double('VSphereCloud::Resources::ResourcePool', mob: resource_pool_mob) }
      let(:resource_pool_mob) { instance_double('VimSdk::Vim::ResourcePool') }

      let(:import_spec) { instance_double('VimSdk::Vim::ImportSpec') }

      let(:template_folder) { instance_double('VSphereCloud::Resources::Folder', mob: template_folder_mob) }
      let(:template_folder_mob) { instance_double('VimSdk::Vim::Folder') }

      let(:nfc_lease) { instance_double('VimSdk::Vim::HttpNfcLease') }

      def perform
        lease_obtainer.obtain(resource_pool, import_spec, template_folder)
      end

      it 'asks the resource pool to create a new entity' do
        allow(client).to receive(:get_property)
          .and_return(VimSdk::Vim::HttpNfcLease::State::READY)

        expect(resource_pool_mob).to receive(:import_vapp)
          .with(import_spec, template_folder_mob, nil)

        perform
      end

      # NfcLeaseState: https://www.vmware.com/support/developer/vc-sdk/visdk400pubs/ReferenceGuide/vim.HttpNfcLease.State.html
      it 'waits untils lease stops initializing' do
        allow(resource_pool_mob).to receive(:import_vapp).and_return(nfc_lease)

        expect(client).to receive(:get_property).ordered
          .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
          .and_return(VimSdk::Vim::HttpNfcLease::State::INITIALIZING)
        expect(subject).to receive(:sleep).ordered.with(1.0)

        expect(client).to receive(:get_property).ordered
          .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
          .and_return(VimSdk::Vim::HttpNfcLease::State::INITIALIZING)
        expect(subject).to receive(:sleep).ordered.with(1.0)

        expect(client).to receive(:get_property).ordered
          .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
          .and_return(VimSdk::Vim::HttpNfcLease::State::READY)

        perform
      end

      context 'when there is an error obtaining the lease' do
        before do
          allow(resource_pool_mob).to receive(:import_vapp).and_return(nfc_lease)
          allow(client).to receive(:get_property)
            .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
            .and_return(VimSdk::Vim::HttpNfcLease::State::ERROR)
        end

        it 'raises an exception with info from the error' do
          nfc_lease_error = double(
            msg: 'fake-error-message',
            fault_cause: 'fake-fault-cause',
            fault_message: [double('fake-fault-message')],
            dynamic_type: 'fake-dynamic-type',
            dynamic_property: [double('fake-dynamic-property')],
          )

          allow(client).to receive(:get_property)
            .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'error')
            .and_return(nfc_lease_error)

          expect {
            perform
          }.to raise_error(RuntimeError,
            /Could not acquire HTTP NFC lease.*fake-error-message.*fake-fault-cause.*fake-fault-message.*fake-dynamic-type.*fake-dynamic-property/)
        end
      end

      context 'when state of the lease becomes ready (means "disks may be transferred")' do
        before do
          allow(resource_pool_mob).to receive(:import_vapp).and_return(nfc_lease)
          allow(client).to receive(:get_property)
            .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
            .and_return(VimSdk::Vim::HttpNfcLease::State::READY)
        end

        it 'returns the lease' do
          expect(perform).to eq(nfc_lease)
        end
      end

      context 'when state of the lease is not ready or error' do
        before do
          allow(resource_pool_mob).to receive(:import_vapp).and_return(nfc_lease)
          allow(client).to receive(:get_property)
            .with(nfc_lease, VimSdk::Vim::HttpNfcLease, 'state')
            .and_return(double('unknown-lease-state')) # could be DONE
        end

        it 'raises an exception with lease state value' do
          expect {
            perform
          }.to raise_error(RuntimeError,
            /Could not acquire HTTP NFC lease \(state is: '.*unknown-lease-state.*'\)/)
        end
      end
    end
  end
end
