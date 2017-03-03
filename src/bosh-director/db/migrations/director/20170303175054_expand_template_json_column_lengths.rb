Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      alter_table(:templates) do
        set_column_type :provides_json, 'longtext'
        set_column_type :consumes_json, 'longtext'
      end
    end
  end
end
