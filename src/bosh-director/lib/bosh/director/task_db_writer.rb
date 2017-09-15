module Bosh::Director
  class TaskDBWriter
    def initialize(column, task_id)
      @column_name = column
      @task_id = task_id
      @transactor = Transactor.new
    end

    def write(text)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        begin
          Models::Task.where(:id => @task_id).update({@column_name => Sequel.join([@column_name, text])})
        rescue Sequel::DatabaseError => e
          # "Incorrect string value" means using utf8, but passing passing chars with more than 3 bytes (need utf8mb4)
          raise e unless e.message =~ /Illegal mix of collations/ || e.message =~ /Incorrect string value/

          ascii_text = text.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '<bosh-non-ascii-char>')
          Models::Task.where(:id => @task_id).update({@column_name => Sequel.join([@column_name, ascii_text])})
        end
      end
    end
  end
end
