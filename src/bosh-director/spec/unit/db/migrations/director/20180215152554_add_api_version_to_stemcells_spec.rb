require_relative '../../../../db_spec_helper'

module Bosh::Director
 describe 'add api_version column to stemcells' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) { '20180215152554_add_api_version_to_stemcells.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'allows to save api_version' do
      DBSpecHelper.migrate(migration_file)
      expect(db[:stemcells].columns).to include(:api_version)

      db[:stemcells] << {
        name: 'ubuntu-stemcell',
        version: '3232.43',
        cid: '68aab7c44c857217641784806e2eeac4a3a99d1c',
        sha1: 'shawone',
        operating_system: 'tesseract',
        cpi: 'cpi',
        api_version: 2,
      }

      expect(db[:stemcells].first[:api_version]).to eq 2
    end

    it 'allows api_version to be nil' do
      DBSpecHelper.migrate(migration_file)
      expect(db[:stemcells].columns).to include(:api_version)

      db[:stemcells] << {
        name: 'ubuntu-stemcell',
        version: '3232.23',
        cid: '68aab7c44c857217641784806e2eeac4a3a99d1c',
        sha1: 'shar2d2',
        operating_system: 'aether',
        cpi: 'cpi',
      }
      expect(db[:stemcells].first[:api_version]).to be_nil
    end
  end
end