require 'spec_helper'

module Bosh::Director
  describe TaskDBWriter do
    subject(:task_db_writer) { TaskDBWriter.new(column_name, task.id) }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:column_name) { :result_output }

    describe '#write' do
      it 'records data to task in db' do
        task_db_writer.write('result')
        task.refresh
        expect(task[:result_output]).to eq('result')
      end

      it 'adds data to existing information in record' do
        expect(task[:result_output]).to eq('')
        task_db_writer.write('result')
        task_db_writer.write('-result1')
        task.refresh
        expect(task[:result_output]).to eq('result-result1')
      end

      context 'database table does not support utf8 data', truncation: true, if: ENV.fetch('DB', 'sqlite') == 'mysql' do
        before { Bosh::Director::Config.db.run('ALTER TABLE tasks CONVERT TO CHARACTER SET latin1 COLLATE latin1_swedish_ci') }
        after { Bosh::Director::Config.db.run('ALTER TABLE tasks CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci') }

        it 'converts utf8 data' do
          task_db_writer.write("code is \u{1F600}!\n")
          task.refresh
          expect(task[:result_output]).to eq("code is <bosh-non-ascii-char>!\n")
        end
      end

      context 'database table does only support utf8 3-byte chars', truncation: true, if: ENV.fetch('DB', 'sqlite') == 'mysql' do
        before do
          Bosh::Director::Config.db.run('ALTER TABLE tasks CONVERT TO CHARACTER SET utf8 COLLATE utf8_unicode_ci')
          Bosh::Director::Config.db.run('SET sql_mode="STRICT_TRANS_TABLES"')
        end
        after { Bosh::Director::Config.db.run('ALTER TABLE tasks CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci') }

        it 'converts utf8 4-byte chars' do
          task_db_writer.write("code is \u{1F600}!\n")
          task.refresh
          expect(task[:result_output]).to eq("code is <bosh-non-ascii-char>!\n")
        end
      end

      context 'database table supports utf8 data', if: ENV.fetch('DB', 'sqlite') != 'mysql' do
        it 'stores utf8 data' do
          task_db_writer.write("code is \u{1F600}!\n")
          task.refresh
          expect(task[:result_output]).to eq("code is \u{1F600}!\n")
        end
      end
    end
  end
end
