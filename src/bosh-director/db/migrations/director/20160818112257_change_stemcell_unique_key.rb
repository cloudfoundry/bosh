Sequel.migration do
  change do
    if [:sqlite].include?(adapter_scheme)

      rename_table(:stemcells, :old_stemcells)

      create_table(:stemcells) do
        primary_key :id
        String :name, null: false
        String :version, null: false
        String :cid, null: false
        String :sha1
        String :operating_system
        String :cpi, default: ''
        unique [:name, :version, :cpi]
      end

      self[:old_stemcells].each do |old_stemcells_row|
        self[:stemcells].insert(old_stemcells_row)
      end

      drop_table(:old_stemcells)

    else # mysql + postgresql

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
end