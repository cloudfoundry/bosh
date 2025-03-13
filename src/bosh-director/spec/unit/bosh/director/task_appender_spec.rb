require 'spec_helper'

module Bosh::Director
  describe TaskAppender do
    subject(:task_appender) do
      TaskAppender.new('EventDBWriter',
                       db_writer: task_db_writer,
                       layout: Logging.layouts.pattern(pattern: '%m\n'))
    end
    let(:logger) { Logging::Logger.new('Log') }

    let(:task_db_writer) { TaskDBWriter.new(column_name, task.id) }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:column_name) { :event_output }

    before do
      logger.add_appenders(task_appender)
    end

    it 'formats with layout' do
      entry = { task: :foo, index: 1, state: 'started', progress: 0 }
      logger.info(JSON.generate(entry))
      task.refresh
      expect(task[:event_output]).to eq("#{JSON.generate(entry)}\n")
    end
  end
end
