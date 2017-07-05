require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'drop users' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170616173221_remove_users_table.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'drops them' do
      db[:users] << {username: 'short-timer', password: 's3kr3t!'}

      DBSpecHelper.migrate(migration_file)

      expect(db.tables).to_not include(:users)
    end
  end
end
