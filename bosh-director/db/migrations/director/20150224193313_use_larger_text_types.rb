Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      set_column_type :tasks, :result, 'longtext'
      set_column_type :vms, :apply_spec_json, 'longtext'
      set_column_type :templates, :properties_json, 'longtext'
    end
  end
end
