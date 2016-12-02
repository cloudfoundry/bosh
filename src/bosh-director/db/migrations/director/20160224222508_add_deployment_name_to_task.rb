Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column :deployment_name, String, default: nil
    end
  end
end
