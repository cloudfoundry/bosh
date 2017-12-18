require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20171210183015_add_job_groups.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'creates the appropriate tables' do
      DBSpecHelper.migrate(migration_file)
      expect(db.table_exists?(:delayed_job_groups)).to be_truthy
      expect(db.table_exists?(:delayed_job_groups_jobs)).to be_truthy
    end

    it 'ensures that fields allow texts longer than 65535 character' do
      DBSpecHelper.migrate(migration_file)

      really_long_text = 'a' * 65536
      db[:delayed_job_groups] << { limit: 5, config_content: really_long_text }

      expect(db[:delayed_job_groups].map { |cp| cp[:config_content].length }).to eq([really_long_text.length])
    end
  end
end
