require 'db_spec_helper'

module Bosh::Director
  describe 'backfill_stemcell_os' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160331225404_backfill_stemcell_os.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'populates stemcell\'s operating system column, if empty' do
      db[:stemcells] << {id: 1, name: 'fake-stem-1', version: 'fake-version-1', cid: 'fake-cid-1'}
      db[:stemcells] << {id: 2, name: 'fake-stem-2', version: 'fake-version-2', cid: 'fake-cid-2', operating_system: 'fake-operating-system'}
      db[:stemcells] << {id: 3, name: 'fake-stem-3', version: 'fake-version-3', cid: 'fake-cid-3', operating_system: ''}
      db[:stemcells] << {id: 4, name: 'fake-stem-4', version: 'fake-version-4', cid: 'fake-cid-4', operating_system: nil}

      DBSpecHelper.migrate(migration_file)

      stemcells = db[:stemcells].all.sort_by{|e| e[:id]}
      expect(stemcells[0][:operating_system]).to eq(stemcells[0][:name])
      expect(stemcells[1][:operating_system]).to eq('fake-operating-system')
      expect(stemcells[2][:operating_system]).to eq(stemcells[2][:name])
      expect(stemcells[3][:operating_system]).to eq(stemcells[3][:name])
    end
  end
end
