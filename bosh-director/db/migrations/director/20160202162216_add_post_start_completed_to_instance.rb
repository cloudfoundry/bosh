Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :post_start_completed, TrueClass, default: true
    end
  end
end