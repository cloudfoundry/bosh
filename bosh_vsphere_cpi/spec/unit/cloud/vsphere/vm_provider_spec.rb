require 'spec_helper'

describe VSphereCloud::VMProvider do
  subject(:vm_provider) { described_class.new(datacenter, client, logger) }
  let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter') }
  let(:client) { instance_double('VSphereCloud::Client') }
  let(:logger) { instance_double('Logger') }

  describe 'find' do
    before do
      allow(datacenter).to receive(:vm_path).with('fake-vm-cid').and_return('fake-vm-path')
    end

    context 'when vm can not be found in any datacenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with('fake-vm-path').and_return(nil)
      end

      it 'raises VMNotFound error' do
        expect {
          vm_provider.find('fake-vm-cid')
        }.to raise_error Bosh::Clouds::VMNotFound
      end
    end

    context 'when vm is found in one of datacenter' do
      let(:vm_mob) { double(:vm) }
      before do
        allow(client).to receive(:find_by_inventory_path).with('fake-vm-path').and_return(vm_mob)
      end

      it 'returns vm' do
        vm = vm_provider.find('fake-vm-cid')
        expect(vm.cid).to eq('fake-vm-cid')
        expect(vm.mob).to eq(vm_mob)
      end
    end
  end
end
