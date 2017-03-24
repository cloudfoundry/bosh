Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column(:started_at, Time)
    end
  end
end
