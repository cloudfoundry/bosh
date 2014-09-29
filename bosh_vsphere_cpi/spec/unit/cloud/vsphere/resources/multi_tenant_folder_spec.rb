require 'spec_helper'

describe VSphereCloud::Resources::MultiTenantFolder do
  let(:client) { instance_double('VSphereCloud::Client') }
  let(:logger) { instance_double('Logger', debug: nil) }
  let(:config) do
    instance_double('VSphereCloud::Config', client: client, logger: logger, datacenter_name: 'fake-datacenter-name')
  end
  let(:parent_folder_mob) { double('fake-folder-mob') }
  let(:sub_folder_mob) { double('fake-uuid_folder-mob') }

  subject(:folder) { described_class.new('fake-parent-folder-name', 'fake-subfolder-name', config) }

  context 'initializing' do
    context 'when the parent folder is not found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          ['fake-datacenter-name', 'vm', 'fake-parent-folder-name']
        ).and_return(nil)
      end

      it 'raises' do
        expect { folder }.to raise_exception(RuntimeError, 'Missing folder: fake-parent-folder-name')
      end
    end

    context 'when the parent folder is found in vcenter' do
      before do
        allow(client).to receive(:find_by_inventory_path).with(
          ['fake-datacenter-name', 'vm', 'fake-parent-folder-name']
        ).and_return(parent_folder_mob)
      end

      it 'should try to create the subfolder' do
        expect(parent_folder_mob).to receive(:create_folder).with('fake-subfolder-name')
        folder
      end

      context "when creating the subfolder fails because it's already been created" do
        before do
          error = VimSdk::Vim::Fault::DuplicateName.new(msg: 'The name "fake-subfolder-name" already exists.')
          soap_error = VimSdk::SoapError.new(error.msg, error)
          allow(parent_folder_mob).to receive(:create_folder).with('fake-subfolder-name').and_raise(soap_error)
          allow(client).to receive(:find_by_inventory_path).with(
            ['fake-datacenter-name', 'vm', ['fake-parent-folder-name', 'fake-subfolder-name']]
          ).and_return(nil)
        end

        it 'should not raise' do
          expect { folder }.not_to raise_error
        end

        it 'logs correct messages' do
          expect(logger).to receive(:debug).with('Attempting to create folder fake-parent-folder-name/fake-subfolder-name').ordered
          expect(logger).to receive(:debug).with(%r{Folder fake-parent-folder-name/fake-subfolder-name already exists}).ordered

          folder
        end
      end

      context 'when creating the subfolder fails for a non-DuplicateName reason' do
        before do
          error = VimSdk::Vim::Fault::InvalidName.new(msg: 'The name "fake-subfolder-name" already exists.')
          soap_error = VimSdk::SoapError.new(error.msg, error)
          allow(parent_folder_mob).to receive(:create_folder).with('fake-subfolder-name').and_raise(soap_error)
        end

        it 'should raise' do
          expect { folder }.to raise_error
        end

        it 'logs correct messages' do
          expect(logger).to receive(:debug).with('Attempting to create folder fake-parent-folder-name/fake-subfolder-name')

          begin
            folder
          rescue
          end
        end
      end

      context 'when creating the subfolder succeeds' do
        before { allow(parent_folder_mob).to receive(:create_folder).and_return(sub_folder_mob) }

        it 'logs correct messages' do
          expect(logger).to receive(:debug).with('Attempting to create folder fake-parent-folder-name/fake-subfolder-name').ordered
          expect(logger).to receive(:debug).with('Created folder fake-parent-folder-name/fake-subfolder-name').ordered

          folder
        end

        it 'sets the mob' do
          expect(folder.mob).to equal(sub_folder_mob)
        end

        it 'sets the folder name' do
          expect(folder.name).to eq(['fake-parent-folder-name', 'fake-subfolder-name'])
        end
      end
    end
  end
end
