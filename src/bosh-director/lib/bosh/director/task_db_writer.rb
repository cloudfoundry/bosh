module Bosh::Director
  class TaskDBWriter
    def initialize(column, task)
      @column_name = column
      @task = task
      @transactor = Transactor.new
    end

    def write(text)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        @task.update({@column_name => "#{@task[@column_name]}#{text}"})
      end
    end
  end
end
