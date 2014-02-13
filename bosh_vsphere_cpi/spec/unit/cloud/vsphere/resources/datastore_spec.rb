require 'spec_helper'

describe VSphereCloud::Resources::Datastore do
  subject(:datastore) {
    VSphereCloud::Resources::Datastore.new(
      :obj => datastore_mob,
      'name' => 'foo_lun',
      'summary.capacity' => 16 * 1024 * 1024 * 1024,
      'summary.freeSpace' => 8 * 1024 * 1024 * 1024
    )
  }

  let(:datastore_mob) { instance_double('VimSdk::Vim::Datastore') }

  describe '#mob' do
    it 'returns the mob' do
      expect(datastore.mob).to eq(datastore_mob)
    end
  end

  describe '#name' do
    it 'returns the name' do
      expect(datastore.name).to eq('foo_lun')
    end
  end

  describe '#total_space' do
    it 'returns the total space' do
      expect(datastore.total_space).to eq(16384)
    end
  end

  describe '#synced_free_space' do
    it 'returns the synced free space' do
      expect(datastore.synced_free_space).to eq(8192)
    end
  end

  describe '#allocated_after_sync' do
    it 'returns the allocated after sync' do
      expect(datastore.allocated_after_sync).to eq(0)
    end
  end

  describe '#free_space' do
    it 'returns the free space' do
      expect(datastore.free_space).to eq(8192)
    end
  end

  describe '#allocate' do
    it 'should allocate space' do
      expect { datastore.allocate(1024) }.to change { datastore.free_space }.by(-1024)
    end
  end

  describe '#inspect' do
    it 'returns the printable form' do
      expect(datastore.inspect).to eq("<Datastore: #{datastore_mob} / foo_lun>")
    end

  end
end
