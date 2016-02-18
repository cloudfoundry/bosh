Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :scopes, String, default: 'bosh.admin'
    end
  end
end
