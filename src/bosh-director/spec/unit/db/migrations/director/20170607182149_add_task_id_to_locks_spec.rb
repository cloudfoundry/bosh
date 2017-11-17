require 'db_spec_helper'

module Bosh::Director
  describe 'Add task id to locks' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170607182149_add_task_id_to_locks.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'adds the task_id column to locks table and defaults it to empty' do
      db[:locks] << {id: 100, name: 'lock1', uid: 'uuid-1', expired_at: Time.now}
      db[:locks] << {id: 200, name: 'lock2', uid: 'uuid-2', expired_at: Time.now}

      DBSpecHelper.migrate(migration_file)

      expect(db[:locks].where(id: 100).first[:task_id]).to eq('')
      expect(db[:locks].where(id: 200).first[:task_id]).to eq('')
    end

    it 'supports adding task ids to lock' do
      DBSpecHelper.migrate(migration_file)
      db[:locks] << {id: 100, name: 'lock1', uid: 'uuid-1', task_id: "task_1", expired_at: Time.now}
      db[:locks] << {id: 200, name: 'lock2', uid: 'uuid-2', expired_at: Time.now}

      expect(db[:locks].where(id: 100).first[:task_id]).to eq('task_1')
      expect(db[:locks].where(id: 200).first[:task_id]).to eq('')
    end

    it 'does NOT support a null value for task_id' do
      DBSpecHelper.migrate(migration_file)

      expect{
        db[:locks] << {id: 100, name: 'lock1', uid: 'uuid-1', task_id: nil, expired_at: Time.now}
      }.to raise_error
    end
  end
end
