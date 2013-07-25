require 'spec_helper'

describe VSphereCloud::Cloud do

  let(:config) {
    {
        'vcenters' => [{
                           'host' => 'host',
                           'user' => 'user',
                           'password' => 'password',
                           'datacenters' => [{
                                                 'name' => 'name',
                                                 'template_folder' => 'template_folder',
                                                 'vm_folder' => 'vm_folder',
                                                 'datastore_pattern' => 'datastore_pattern',
                                                 'persistent_datastore_pattern' => 'persistent_datastore_pattern',
                                                 'disk_path' => 'disk_path',
                                                 'clusters' => []
                                             }]
                       }],
        'agent' => {},
    }
  }

  let(:client) { double(VSphereCloud::Client) }

  subject { described_class.new(config) }

  before(:each) do
    client.stub(:login)
    client.stub_chain(:stub, :cookie).and_return('a=1')

    described_class.any_instance.stub(:setup_at_exit)

    VSphereCloud::Client.stub(new: client)
  end

  describe 'has_vm?' do

    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do

      it 'returns true' do
        subject.should_receive(:get_vm_by_cid).with(vm_id)
        expect(subject.has_vm?(vm_id)).to be_true
      end
    end

    context 'the vm is not found' do

      it 'returns false' do
        subject.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(subject.has_vm?(vm_id)).to be_false
      end


    end

  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect {subject.snapshot_disk('123')}.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe ''


end
