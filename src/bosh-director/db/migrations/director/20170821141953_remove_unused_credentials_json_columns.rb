Sequel.migration do
  change do
    alter_table(:instances) do
      drop_column :credentials_json_bak
    end

    alter_table(:vms) do
      drop_column :credentials_json
    end
  end
end
