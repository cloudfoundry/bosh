require 'db_spec_helper'

module Bosh::Director
  describe 'adding event_output and result_output to tasks' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161128181900_add_logs_to_tasks.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'adds result_output and event_output columns' do
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

      expect(db[:tasks].map{|cp| cp[:result_output]}).to eq([nil])
      expect(db[:tasks].map{|cp| cp[:event_output]}).to eq([nil])
    end

    it 'ensures that fields allow texts longer than 65535 character' do
      DBSpecHelper.migrate(migration_file)

      really_long_text = 'a' * 65536
      db[:tasks] << {
        id: 1,
        state: 'finished',
        type: 'something',
        deployment_name: 'test-deployment',
        timestamp: '2016-04-14 11:53:42',
        description: 'description',
        result_output: really_long_text,
        event_output: really_long_text
      }

      expect(db[:tasks].map{|cp| cp[:result_output].length}).to eq([really_long_text.length])
      expect(db[:tasks].map{|cp| cp[:event_output].length}).to eq([really_long_text.length])
    end
  end

end
