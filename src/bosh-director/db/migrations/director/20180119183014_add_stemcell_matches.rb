Sequel.migration do
  up do
    create_table(:stemcell_matches) do
      primary_key :id
      String :name
      String :version
      String :cpi
      unique [:name, :version, :cpi]
    end
  end
end
