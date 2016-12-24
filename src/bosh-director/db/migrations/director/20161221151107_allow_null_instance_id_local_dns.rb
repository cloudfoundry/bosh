Sequel.migration do
  change do
    alter_table :local_dns_records do
      set_column_allow_null(:instance_id)
    end
  end
end
