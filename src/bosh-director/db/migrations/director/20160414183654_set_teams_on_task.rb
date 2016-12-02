Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column(:teams, String)
    end
  end
end
