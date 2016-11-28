Sequel.migration do
  change do
    alter_table(:deployments) do
      drop_column(:scopes)
      add_column :teams, String
    end
  end
end
