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

  context 'when the folder is not found in vcenter' do
    before do
      allow(config).to receive(:datacenter_use_sub_folder).and_return(false)
      allow(client).to receive(:find_by_inventory_path).with(
                         ['fake-datacenter-name', 'vm', 'fake-folder-name']).and_return(nil)
    end

    it 'raises' do
      expect { folder }.to raise_exception(RuntimeError, 'Missing folder: fake-folder-name')
    end
  end

  context 'when the folder is found in vcenter' do
    before do
      allow(client).to receive(:find_by_inventory_path).with(
                         ['fake-datacenter-name', 'vm', 'fake-folder-name']).and_return(folder_mob)
    end

    describe '#mob' do
      context 'multi-tenancy' do
        before { allow(config).to receive(:datacenter_use_sub_folder).and_return(true) }

        context 'when the director uuid folder exists' do
          before do
            allow(client).to receive(:find_by_inventory_path).with(
                               ['fake-datacenter-name', 'vm', ['fake-folder-name', '6666']]).and_return(uuid_folder_mob)
          end

          it 'returns the mob of the director uuid folder' do
            expect(folder.mob).to eq(uuid_folder_mob)
          end
        end

        context 'when the director uuid folder does not exist' do
          before do
            allow(client).to receive(:find_by_inventory_path).with(
                               ['fake-datacenter-name', 'vm', ['fake-folder-name', '6666']]).and_return(nil)
          end

          it 'creates it' do
            expect(folder_mob).to receive(:create_folder).with('6666')
            folder.mob
          end

          it 'returns the mob of the director uuid folder' do
            allow(folder_mob).to receive(:create_folder).with('6666').and_return(uuid_folder_mob)
            expect(folder.mob).to eq(uuid_folder_mob)
          end

          it 'logs correct messages' do
            allow(folder_mob).to receive(:create_folder).with('6666')

            expect(logger).to receive(:debug).with('Search for folder fake-folder-name/6666')
            expect(logger).to receive(:debug).with('Creating folder fake-folder-name/6666')
            expect(logger).to receive(:debug).with(%r{Found folder fake-folder-name/6666: })

            folder.mob
          end
        end
      end

      context 'not multi-tenancy' do
        before { allow(config).to receive(:datacenter_use_sub_folder).and_return(false) }

        it 'returns the mob of the folder name' do
          expect(folder.mob).to eq(folder_mob)
        end
      end
    end

    describe '#name' do
      context 'multi-tenancy' do
        before do
          allow(config).to receive(:datacenter_use_sub_folder).and_return(true)
          allow(client).to receive(:find_by_inventory_path).with(
                             ['fake-datacenter-name', 'vm', ['fake-folder-name', '6666']]).and_return(uuid_folder_mob)
        end

        it 'uses the director uuid as a namespace' do
          expect(folder.name).to eq(['fake-folder-name', '6666'])
        end

        it 'logs the correct messages' do
          expect(logger).to receive(:debug).with('Search for folder fake-folder-name/6666')
          expect(logger).to receive(:debug).with(%r{Found folder fake-folder-name/6666: })

          folder.name
        end
      end

      context 'not multi-tenancy' do
        before { allow(config).to receive(:datacenter_use_sub_folder).and_return(false) }

        it 'uses the folder name' do
          expect(folder.name).to eq('fake-folder-name')
        end
      end
    end
  end
end
