Sequel.migration do
  up do
    alter_table :local_dns_records do
      add_column :links_json, String
    end
  end
end
