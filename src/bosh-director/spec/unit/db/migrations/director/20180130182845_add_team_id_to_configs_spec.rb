require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add column to configs table' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20180130182845_add_team_id_to_configs.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'allows to save team_id' do
      DBSpecHelper.migrate(migration_file)
      expect(db[:configs].columns).to include(:team_id)

      db[:configs] << {
        name: 'config',
        type: 'type',
        content: '',
        created_at: Time.now,
        team_id: 1,
      }

      expect(db[:configs].first[:team_id]).to eq 1
    end

    it 'allows team_id to be nil' do
      DBSpecHelper.migrate(migration_file)
      expect(db[:configs].columns).to include(:team_id)

      db[:configs] << {
        name: 'config',
        type: 'type',
        content: '',
        created_at: Time.now,
      }

      expect(db[:configs].first[:team_id]).to be_nil
    end
  end
end
