Sequel.migration do
  up do
    alter_table :local_dns_records do
      add_column :links_json, String, text: true
    end

    set_column_type :local_dns_records, :links_json, 'longtext' if %i[mysql2 mysql].include?(adapter_scheme)
  end
end
