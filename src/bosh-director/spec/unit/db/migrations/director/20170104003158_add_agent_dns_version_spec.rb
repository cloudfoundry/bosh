require 'db_spec_helper'

module Bosh::Director
  describe 'adding context id to tasks' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170104003158_add_agent_dns_version.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'creates the table' do
      DBSpecHelper.migrate(migration_file)
      db[:agent_dns_versions] << { agent_id: 'abc', dns_version: 3 }
      agent_dns_version = db[:agent_dns_versions].first
      expect(agent_dns_version[:agent_id]).to eq('abc')
      expect(agent_dns_version[:dns_version]).to eq(3)
    end
  end
end
