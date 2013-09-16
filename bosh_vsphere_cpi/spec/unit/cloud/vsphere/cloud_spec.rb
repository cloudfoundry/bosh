require 'spec_helper'

describe VSphereCloud::Cloud do
  let(:client_stub) { double(cookie: nil) }
  let(:client) { instance_double('VSphereCloud::Client', login: nil, logout: nil, stub: client_stub) }
  let(:config) { { fake: 'config' } }

  subject(:vsphere_cloud) { VSphereCloud::Cloud.new(config) }

  before do
    VSphereCloud::Config.should_receive(:configure).with(config)
    VSphereCloud::Cloud.any_instance.stub(:at_exit)
    VSphereCloud::Client.stub(new: client)
  end

  describe 'has_vm?' do
    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do
      it 'returns true' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id)
        expect(vsphere_cloud.has_vm?(vm_id)).to be_true
      end
    end

    context 'the vm is not found' do
      it 'returns false' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(vsphere_cloud.has_vm?(vm_id)).to be_false
      end
    end
  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect { vsphere_cloud.snapshot_disk('123') }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end
end
