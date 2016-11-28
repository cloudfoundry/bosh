Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      alter_table :deployments do
        set_column_type :manifest, 'longtext'
      end
    end
  end
end
