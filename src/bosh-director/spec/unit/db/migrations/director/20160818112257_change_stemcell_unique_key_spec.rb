require 'db_spec_helper'

module Bosh::Director
  describe 'change stemcell unique key' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160818112257_change_stemcell_unique_key.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'allows stemcell records with same name, version when cpi differs' do
      db[:stemcells] << {name: 'stemcell1', version: 'stemcell-version', cid: 'cid1'}
      expect {
        db[:stemcells] << {name: 'stemcell1', version: 'stemcell-version', cid: 'cid2'}
      }.to raise_error Sequel::UniqueConstraintViolation

      DBSpecHelper.migrate(migration_file)

      # same cpi: fails
      db[:stemcells] << {name: 'stemcell3', version: 'stemcell-version', cid: 'cid1', cpi: 'cpi1'}
      expect {
        db[:stemcells] << {name: 'stemcell3', version: 'stemcell-version', cid: 'cid2', cpi: 'cpi1'}
      }.to raise_error Sequel::UniqueConstraintViolation

      # different cpi: works
      db[:stemcells] << {name: 'stemcell2', version: 'stemcell-version', cid: 'cid1', cpi: 'cpi1'}
      db[:stemcells] << {name: 'stemcell2', version: 'stemcell-version', cid: 'cid2', cpi: 'cpi2'}
    end
  end
end
