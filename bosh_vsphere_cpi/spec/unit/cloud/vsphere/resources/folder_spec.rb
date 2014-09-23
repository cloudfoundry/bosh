require 'spec_helper'

describe VSphereCloud::Resources::Folder do
  let(:client) { instance_double('VSphereCloud::Client') }
  let(:logger) { instance_double('Logger', debug: nil) }
  let(:config) do
    instance_double('VSphereCloud::Config', client: client, logger: logger, datacenter_name: 'fake-datacenter-name')
  end
  let(:folder_mob) { double('fake-folder-mob') }
  let(:uuid_folder_mob) { double('fake-uuid_folder-mob') }

  subject(:folder) { described_class.new('fake-folder-name', config) }

  before { allow(Bosh::Clouds::Config).to receive(:uuid).and_return('6666') }

  context 'initializing' do
    context 'when the folder is not found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          ['fake-datacenter-name', 'vm', 'fake-folder-name']
        ).and_return(nil)
      end

      it 'raises' do
        expect { folder }.to raise_exception(RuntimeError, 'Missing folder: fake-folder-name')
      end
    end

    context 'when the folder is found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          ['fake-datacenter-name', 'vm', 'fake-folder-name']
        ).and_return(folder_mob)
      end

      it 'should not raise' do
        expect { folder }.not_to raise_error
      end

      it 'sets the mob' do
        expect(folder.mob).to equal(folder_mob)
      end

      it 'sets the folder name' do
        expect(folder.name).to eq('fake-folder-name')
      end
    end
  end
end
