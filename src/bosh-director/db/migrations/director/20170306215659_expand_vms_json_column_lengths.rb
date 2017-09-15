Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      alter_table(:vms) do
        set_column_type :credentials_json, 'longtext'
        set_column_type :env_json, 'longtext'
      end
    end
  end
end
