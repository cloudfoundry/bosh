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

  describe '#mob' do
    before do
      allow(client).to receive(:find_by_inventory_path).with(
        ['fake-datacenter-name', 'vm', 'fake-folder-name']
      ).and_return(folder_mob)
    end

    context 'multi-tenancy' do
      before do
        allow(config).to receive(:datacenter_use_sub_folder).and_return(true)
        allow(folder_mob).to receive(:create_folder).with('6666').and_return(uuid_folder_mob)
      end

      it 'returns the mob of the subfolder' do
        expect(folder.mob).to eq(uuid_folder_mob)
      end
    end

    context 'not multi-tenancy' do
      before { allow(config).to receive(:datacenter_use_sub_folder).and_return(false) }

      it 'returns the mob of the folder' do
        expect(folder.mob).to eq(folder_mob)
      end
    end
  end

  describe '#name' do
    before do
      allow(client).to receive(:find_by_inventory_path).with(
        ['fake-datacenter-name', 'vm', 'fake-folder-name']
      ).and_return(folder_mob)
    end

    context 'multi-tenancy' do
      before do
        allow(config).to receive(:datacenter_use_sub_folder).and_return(true)
        allow(folder_mob).to receive(:create_folder).and_return(uuid_folder_mob)
      end

      it 'uses the director uuid as a namespace' do
        expect(folder.name).to eq(['fake-folder-name', '6666'])
      end
    end

    context 'not multi-tenancy' do
      before { allow(config).to receive(:datacenter_use_sub_folder).and_return(false) }

      it 'uses the folder name' do
        expect(folder.name).to eq('fake-folder-name')
      end
    end
  end

  context "initializing" do
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

      context 'multi-tenancy' do
        before { allow(config).to receive(:datacenter_use_sub_folder).and_return(true) }

        it "should try to create the subfolder" do
          expect(folder_mob).to receive(:create_folder).with('6666')
          folder
        end

        context "when creating the subfolder fails because it's already been created" do
          before do
            error = VimSdk::Vim::Fault::DuplicateName.new(msg: 'The name "6666" already exists.')
            soap_error = VimSdk::SoapError.new(error.msg, error)
            allow(folder_mob).to receive(:create_folder).with('6666').and_raise(soap_error)
            allow(client).to receive(:find_by_inventory_path).with(
              ['fake-datacenter-name', 'vm', ['fake-folder-name', '6666']]
            ).and_return(nil)
          end

          it "should not raise" do
            expect { folder }.not_to raise_error
          end

          it 'logs correct messages' do
            expect(logger).to receive(:debug).with('Attempting to create folder fake-folder-name/6666').ordered
            expect(logger).to receive(:debug).with(%r{Folder fake-folder-name/6666 already exists}).ordered

            folder
          end
        end

        context "when creating the subfolder fails for a non-DuplicateName reason" do
          before do
            error = VimSdk::Vim::Fault::InvalidName.new(msg: 'The name "6666" already exists.')
            soap_error = VimSdk::SoapError.new(error.msg, error)
            allow(folder_mob).to receive(:create_folder).with('6666').and_raise(soap_error)
          end

          it "should raise" do
            expect { folder }.to raise_error
          end

          it 'logs correct messages' do
            expect(logger).to receive(:debug).with('Attempting to create folder fake-folder-name/6666')

            begin
              folder
            rescue
            end
          end
        end

        context "when creating the subfolder succeeds" do
          before { allow(folder_mob).to receive(:create_folder).and_return(uuid_folder_mob) }

          it 'logs correct messages' do
            expect(logger).to receive(:debug).with('Attempting to create folder fake-folder-name/6666').ordered
            expect(logger).to receive(:debug).with('Created folder fake-folder-name/6666').ordered

            folder
          end
        end
      end
    end
  end
end
