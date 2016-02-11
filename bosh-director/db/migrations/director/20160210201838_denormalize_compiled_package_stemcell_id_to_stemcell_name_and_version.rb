Sequel.migration do
  change do
    alter_table(:compiled_packages) do
      add_column :stemcell_os, String
      add_column :stemcell_version, String
      set_column_allow_null :stemcell_id, true
    end

    self[:compiled_packages].each do |compiled_package|
      next unless compiled_package[:stemcell_id]

      stemcell = self[:stemcells].filter(id: compiled_package[:stemcell_id]).first

      self[:compiled_packages].filter(id: compiled_package[:id]).update(
        stemcell_os: stemcell[:operating_system],
        stemcell_version: stemcell[:version]
      )
    end
  end
end
