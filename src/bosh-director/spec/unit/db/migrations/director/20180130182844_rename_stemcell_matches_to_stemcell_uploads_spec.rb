require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180130182844_rename_stemcell_matches_to_stemcell_uploads.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'renames stemcell_matches table to stemcell_uploads' do
      db[:stemcell_matches] << { name: 'stemcell', version: '1.1', cpi: 'aws' }
      expect(db[:stemcell_matches].all.count).to eq(1)

      DBSpecHelper.migrate(subject)

      record = db[:stemcell_uploads].all[0]
      expect(record[:name]).to eq('stemcell')
      expect(record[:version]).to eq('1.1')
      expect(record[:cpi]).to eq('aws')
    end
  end
end
