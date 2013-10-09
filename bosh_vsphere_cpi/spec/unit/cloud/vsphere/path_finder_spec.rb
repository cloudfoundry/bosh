require 'spec_helper'
require 'cloud/vsphere/path_finder'

describe VSphereCloud::PathFinder do
  describe '#build_path_for_network' do
    let(:datacenter) { double(name: 'fake_datacenter') }
    let(:root_folder) { double(parent: datacenter, name: 'hidden_folder') }
    let(:parent_folder) { double(parent: root_folder, name: 'parent_folder') }
    let(:managed_object) { double(parent: parent_folder, name: 'fake_managed_object') }

    subject(:path_finder) { VSphereCloud::PathFinder.new }

    it 'returns path for managed object' do
      datacenter.stub(:instance_of?).with(VimSdk::Vim::Datacenter).and_return(true)

      expect(path_finder.path(managed_object)).to eq('parent_folder/fake_managed_object')
    end
  end
end
