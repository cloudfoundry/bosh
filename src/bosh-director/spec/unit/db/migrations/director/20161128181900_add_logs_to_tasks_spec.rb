require 'db_spec_helper'

module Bosh::Director
  describe 'adding event_output and result_output to tasks' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161128181900_add_logs_to_tasks.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'sets the default value of the event_output and result_output to empty string' do
      db[:tasks] << {
        id: 1,
        state: 'finished',
        type: 'something',
        deployment_name: 'test-deployment',
        timestamp: '2016-04-14 11:53:42',
        description: 'description',
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:tasks].columns.include?(:result_output)).to be_truthy
      expect(db[:tasks].columns.include?(:event_output)).to be_truthy
    end
  end
end
