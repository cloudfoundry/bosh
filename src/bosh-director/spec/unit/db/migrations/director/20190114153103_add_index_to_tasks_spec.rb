require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190114153103_add_index_to_tasks.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20190114153103_add_index_to_tasks.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:tasks] << { id: 1, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
      db[:tasks] << { id: 2, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
      db[:tasks] << { id: 3, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
    end

    context 'before migration' do
      it 'should NOT have indexes associated with tasks table' do
        expect(db.indexes(:tasks)).to_not have_key(:tasks_type_index)
      end
    end

    context 'after migration' do
      before do
        DBSpecHelper.migrate(migration_file)
      end
      it 'should add index to type aft' do
        expect(db.indexes(:tasks)).to have_key(:tasks_type_index)
      end
    end
  end
end
