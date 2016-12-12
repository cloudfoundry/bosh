Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column(:event_output, String, :text => true)
      add_column(:result_output, String, :text => true)
    end

    if [:mysql2, :mysql].include?(adapter_scheme)
      set_column_type :tasks, :event_output, 'longtext'
      set_column_type :tasks, :result_output, 'longtext'
    end
  end
end
