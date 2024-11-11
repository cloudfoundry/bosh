Sequel.migration do
  up do
    alter_table(:vms) do
      add_column :permanent_nats_credentials, 'boolean', null: false, default: false
    end
  end
  down do
    alter_table(:vms) do
      drop_column :permanent_nats_credentials
    end
  end
end
