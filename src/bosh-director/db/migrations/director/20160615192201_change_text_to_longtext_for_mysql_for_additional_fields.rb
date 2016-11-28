Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      set_column_type :events, :error, 'longtext'
      set_column_type :events, :context_json, 'longtext'
      set_column_type :delayed_jobs, :handler, 'longtext'
      set_column_type :delayed_jobs, :last_error, 'longtext'
    end
  end
end
