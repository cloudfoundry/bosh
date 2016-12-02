Sequel.migration do
  change do
    alter_table(:stemcells) do
      add_column :operating_system, String
    end
  end
end