Sequel.migration do
  up do
    alter_table(:configs) do
      add_column :team_id, Integer
    end
  end
end
