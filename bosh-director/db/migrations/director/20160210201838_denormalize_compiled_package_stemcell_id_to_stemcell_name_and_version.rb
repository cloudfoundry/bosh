Sequel.migration do
  change do
    alter_table(:compiled_packages) do
      add_column :stemcell_os, String
      add_column :stemcell_version, String
    end

    self[:compiled_packages].each do |compiled_package|
      next unless compiled_package[:stemcell_id]

      stemcell = self[:stemcells].filter(id: compiled_package[:stemcell_id]).first

      self[:compiled_packages].filter(id: compiled_package[:id]).update(
        stemcell_os: stemcell[:operating_system],
        stemcell_version: stemcell[:version]
      )
    end

    if [:mysql2, :mysql].include?(adapter_scheme)
      foreign_key = foreign_key_list(:compiled_packages).find { |constraint| constraint.fetch(:columns) == [:stemcell_id] }.fetch(:name)
      alter_table(:compiled_packages) do
        drop_constraint(foreign_key, {type: :foreign_key})
      end
    end

    alter_table(:compiled_packages) do
      drop_column :stemcell_id
    end
  end
end
