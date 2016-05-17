Sequel.migration do
  change do
    alter_table(:instances) do
      add_column(:ignore, TrueClass, :default => false)
    end
  end
end
