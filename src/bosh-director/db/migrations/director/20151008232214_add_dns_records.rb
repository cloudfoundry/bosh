Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :dns_records, String, text: true
    end
  end
end
