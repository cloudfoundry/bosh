module Bosh::Director
  class TaskDBWriter
    def initialize(column, task_id)
      @column_name = column
      @task_id = task_id
      @transactor = Transactor.new
    end

    def write(text)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        Models::Task.where(:id => @task_id).update({@column_name => Sequel.join([@column_name, text])})
      end
    end
  end
end
