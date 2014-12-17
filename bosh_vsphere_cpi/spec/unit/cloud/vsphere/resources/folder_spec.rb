require 'spec_helper'

describe VSphereCloud::Resources::Folder do
  subject(:folder) { described_class.new(folder_path, config) }
  let(:folder_path) { ['fake-folder-name'] }

  let(:client) { instance_double('VSphereCloud::Client') }
  let(:logger) { instance_double('Logger', debug: nil) }
  let(:config) do
    instance_double('VSphereCloud::Config', client: client, logger: logger, datacenter_name: 'fake-datacenter-name')
  end
  let(:folder_mob) { double(:fake_folder_mob) }
  let(:uuid_folder_mob) { double(:fake_uuid_folder_mob) }

  let(:datacenter_vm_folder_mob) { double(:datacenter_vm_folder_mob) }
  before do
    allow(client).to receive(:find_by_inventory_path).
      with(%w[fake-datacenter-name vm]).and_return(datacenter_vm_folder_mob)
  end

  before { allow(Bosh::Clouds::Config).to receive(:uuid).and_return('6666') }

  context 'initializing' do
    context 'when the folder is found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-folder-name]
        ).and_return(folder_mob)
      end

      it 'returns the folder' do
        expect(folder.mob).to equal(folder_mob)
        expect(folder.path).to eq(['fake-folder-name'])
      end
    end

    context 'when folder is not found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-folder-name]
        ).and_return(nil)
      end

      it 'creates the folder' do
        expect(datacenter_vm_folder_mob).to receive(:create_folder).with('fake-folder-name').and_return(folder_mob)

        expect(folder.mob).to equal(folder_mob)
        expect(folder.path).to eq(['fake-folder-name'])
      end

      context 'when creating folder fails' do
        let(:error) { RuntimeError.new('fake-error') }

        before do
          allow(datacenter_vm_folder_mob).to receive(:create_folder).with('fake-folder-name').and_raise(error)
        end

        it 'raises an error' do
          expect {
            folder
          }.to raise_error(error)
        end
      end

      context 'when creating folder fails because it already exists' do
        before do
          error = VimSdk::Vim::Fault::DuplicateName.new(msg: 'The name "fake-folder-name" already exists.')
          soap_error = VimSdk::SoapError.new(error.msg, error)
          allow(client).to receive(:create_folder).with('fake-folder-name').and_raise(soap_error)
          allow(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm fake-folder-name]
          ).and_return(folder_mob)
        end

        it 'returns the folder' do
          expect(folder.mob).to equal(folder_mob)
          expect(folder.path).to eq(['fake-folder-name'])
        end
      end
    end

    context 'when parent folders are not found in vcenter' do
      let(:folder_path) { %w[fake-grandparent-folder-name fake-parent-folder-name fake-folder-name] }
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-grandparent-folder-name fake-parent-folder-name fake-folder-name]
        ).and_return(nil)

        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-grandparent-folder-name fake-parent-folder-name]
        ).and_return(nil)

        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-grandparent-folder-name]
        ).and_return(nil)
      end

      it 'creates all parent folders' do
        grandparent_folder_mob = double(:grandparent_folder_mob)
        expect(datacenter_vm_folder_mob).to receive(:create_folder).
          with('fake-grandparent-folder-name').and_return(grandparent_folder_mob)

        parent_folder_mob = double(:parent_folder_mob)
        expect(grandparent_folder_mob).to receive(:create_folder).
          with('fake-parent-folder-name').and_return(parent_folder_mob)

        expect(parent_folder_mob).to receive(:create_folder).
          with('fake-folder-name').and_return(folder_mob)

        expect(folder.mob).to equal(folder_mob)
        expect(folder.path).to eq(%w[fake-grandparent-folder-name fake-parent-folder-name fake-folder-name])
      end
    end
  end
end
