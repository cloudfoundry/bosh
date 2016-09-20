Sequel.migration do
  change do
    old_constraint = [:name, :version]
    existing_constraint = self.indexes(:stemcells).find do |_, v|
      v[:columns] == old_constraint
    end

    if existing_constraint
      if [:mysql2, :mysql].include?(adapter_scheme)
        alter_table(:stemcells) do
          drop_index old_constraint, name: existing_constraint.first
        end
      else
        alter_table(:stemcells) do
          drop_constraint existing_constraint.first
        end
      end
    end

    alter_table(:stemcells) do
      add_unique_constraint([:name, :version, :cpi], :name => 'stemcells_name_version_cpi_key')
    end
  end
end