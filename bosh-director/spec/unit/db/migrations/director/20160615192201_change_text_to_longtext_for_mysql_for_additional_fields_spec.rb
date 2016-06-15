require 'db_spec_helper'

module Bosh::Director
  describe 'changed_text_to_longtext_for_mysql' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'migrates data over without data loss' do
      error = Exception.new('oh noes!')
      db[:events] << {
        user: 'user1',
        timestamp: Time.now,
        action: 'action',
        object_type: 'object_type',
        error: error.to_s,
        context_json: '{"error"=>"boo"}'
      }
      db[:delayed_jobs] << {
        priority: 1,
        attempts: 2,
        handler: 'handler',
        last_error: 'last_error'
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:events].map{|cp| cp[:error]}).to eq([error.to_s])
      expect(db[:events].map{|cp| cp[:context_json]}).to eq(['{"error"=>"boo"}'])
      expect(db[:delayed_jobs].map{|cp| cp[:handler]}).to eq(['handler'])
      expect(db[:delayed_jobs].map{|cp| cp[:last_error]}).to eq(['last_error'])
    end
  end
end
