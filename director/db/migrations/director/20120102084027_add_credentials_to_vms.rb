Sequel.migration do
  change do
    alter_table(:vms) do
      add_column :credentials_json, String, :text => true
    end
  end
end
