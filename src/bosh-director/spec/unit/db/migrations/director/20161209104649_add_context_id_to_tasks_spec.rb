require 'db_spec_helper'

module Bosh::Director
  describe 'adding context id to tasks' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161209104649_add_context_id_to_tasks.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'sets the default value of the context_id to empty string' do
      db[:tasks] << {id: 1, state: 'alabama', timestamp: '2016-12-09 11:53:42', description: 'descr', type: 'type'}

      DBSpecHelper.migrate(migration_file)

      expect(db[:tasks].first[:context_id]).to eq('')
    end

    context 'context length' do
      before do
        skip 'SQL lite does not support limiting string size' if [:sqlite].include?(db.adapter_scheme)
      end

      it 'allows 64 chars in length' do
        validContextId = "x" * 64

        DBSpecHelper.migrate(migration_file)
        db[:tasks] << {id: 1, state: 'alabama', timestamp: '2016-12-09 11:53:42', description: 'descr', type: 'type', context_id: validContextId}

        expect(db[:tasks].first[:context_id]).to eq(validContextId)
      end
    end
  end
end
