Sequel.migration do
  down do
    alter_table(:instances) do
      add_column :dns_records, String, text: true
    end
  end

  up do
    alter_table(:instances) do
      drop_column :dns_records
    end
  end
end
