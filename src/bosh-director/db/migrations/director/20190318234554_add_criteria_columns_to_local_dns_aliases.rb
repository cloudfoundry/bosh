Sequel.migration do
  up do
    alter_table(:local_dns_aliases) do
      drop_column :target

      add_column :health_filter, String
      add_column :initial_health_check, String
      add_column :group_id, String

      add_column :placeholder_type, String
    end
  end
end
