require 'spec_helper'

describe VSphereCloud::Resources::Folder do
  subject(:folder) { VSphereCloud::Resources::Folder.new(folder_path, logger, client, datacenter_name) }
  let(:folder_path) { 'fake-parent-folder-name/fake-sub-folder-name' }

  let(:client) { instance_double('VSphereCloud::Client') }
  let(:logger) { instance_double('Logger', debug: nil) }
  let(:datacenter_name) { 'fake-datacenter-name' }
  let(:parent_folder_mob) { double(:fake_parent_folder_mob) }
  let(:sub_folder_mob) { double(:fake_sub_folder_mob) }

  let(:datacenter_vm_folder_mob) { double(:datacenter_vm_folder_mob) }
  before do
    allow(client).to receive(:find_by_inventory_path).
      with(%w[fake-datacenter-name vm]).and_return(datacenter_vm_folder_mob)
  end

  context 'initializing' do
    context 'when the folder is found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-parent-folder-name fake-sub-folder-name]
        ).and_return(sub_folder_mob)
      end

      it 'returns the folder' do
        expect(folder.mob).to equal(sub_folder_mob)
        expect(folder.path).to eq('fake-parent-folder-name/fake-sub-folder-name')
        expect(folder.path_components).to eq(['fake-parent-folder-name', 'fake-sub-folder-name'])
      end
    end

    context 'when sub folder is not found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-parent-folder-name fake-sub-folder-name]
        ).and_return(nil)

        allow(client).to receive(:find_by_inventory_path).with(
          %w[fake-datacenter-name vm fake-parent-folder-name]
        ).and_return(parent_folder_mob)
      end

      it 'creates the sub folder' do
        expect(parent_folder_mob).to receive(:create_folder).with('fake-sub-folder-name').and_return(sub_folder_mob)

        expect(folder.mob).to equal(sub_folder_mob)
        expect(folder.path).to eq('fake-parent-folder-name/fake-sub-folder-name')
        expect(folder.path_components).to eq(['fake-parent-folder-name', 'fake-sub-folder-name'])
      end

      context 'when creating folder fails' do
        let(:error) { RuntimeError.new('fake-error') }

        before do
          allow(parent_folder_mob).to receive(:create_folder).with('fake-sub-folder-name').and_raise(error)
        end

        it 'raises an error' do
          expect {
            folder
          }.to raise_error(error)
        end
      end

      context 'when creating folder fails because it already exists' do
        before do
          error = VimSdk::Vim::Fault::DuplicateName.new(msg: 'The name "fake-sub-folder-name" already exists.')
          soap_error = VimSdk::SoapError.new(error.msg, error)
          allow(parent_folder_mob).to receive(:create_folder).with('fake-sub-folder-name').and_raise(soap_error)
          allow(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm fake-parent-folder-name fake-sub-folder-name]
          ).and_return(nil, sub_folder_mob)
        end

        it 'returns the folder' do
          expect(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm fake-parent-folder-name fake-sub-folder-name]
          ).twice

          expect(folder.mob).to equal(sub_folder_mob)
          expect(folder.path).to eq('fake-parent-folder-name/fake-sub-folder-name')
          expect(folder.path_components).to eq(['fake-parent-folder-name', 'fake-sub-folder-name'])
        end
      end
    end

    context 'when parent folders are not found in vcenter' do
      let(:folder_path) { 'fake-grandparent-folder-name/fake-parent-folder-name/fake-folder-name' }
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

        expect(grandparent_folder_mob).to receive(:create_folder).
          with('fake-parent-folder-name').and_return(parent_folder_mob)

        expect(parent_folder_mob).to receive(:create_folder).
          with('fake-folder-name').and_return(sub_folder_mob)

        expect(folder.mob).to equal(sub_folder_mob)
        expect(folder.path).to eq('fake-grandparent-folder-name/fake-parent-folder-name/fake-folder-name')
        expect(folder.path_components).to eq(%w[fake-grandparent-folder-name fake-parent-folder-name fake-folder-name])
      end
    end

    context 'when root vm folder are not found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm fake-parent-folder-name fake-sub-folder-name]
          ).and_return(nil)

        allow(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm fake-parent-folder-name]
          ).and_return(nil)

        allow(client).to receive(:find_by_inventory_path).with(
            %w[fake-datacenter-name vm]
          ).and_return(nil)
      end

      it 'raise an error' do
        expect{folder.mob}.to raise_error("Root VM Folder not found: fake-datacenter-name/vm")
      end
    end
  end
end
