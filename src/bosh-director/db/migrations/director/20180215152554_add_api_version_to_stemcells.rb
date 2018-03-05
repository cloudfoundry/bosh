Sequel.migration do
  up do
    alter_table(:stemcells) do
      add_column :api_version, Integer
    end
  end
end
