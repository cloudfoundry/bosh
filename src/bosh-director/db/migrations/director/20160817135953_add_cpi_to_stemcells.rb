Sequel.migration do
  change do
    alter_table(:stemcells) do
      add_column(:cpi, String, default: '')
    end
  end
end
