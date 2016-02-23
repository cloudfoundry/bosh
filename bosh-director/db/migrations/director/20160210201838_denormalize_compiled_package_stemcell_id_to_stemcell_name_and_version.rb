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

    foreign_key = foreign_key_list(:compiled_packages).find { |constraint| constraint.fetch(:columns) == [:stemcell_id] }.fetch(:name)
    build_index = indexes(:compiled_packages).find { |_, value| value.fetch(:columns) == [:package_id, :stemcell_id, :build] }.first
    dependency_key_index = indexes(:compiled_packages).find { |_, value| value.fetch(:columns) == [:package_id, :stemcell_id, :dependency_key_sha1] }.first
    alter_table(:compiled_packages) do
      drop_constraint(foreign_key, :type=>:foreign_key)
      drop_constraint(build_index)
      add_index [:package_id, :stemcell_os, :stemcell_version, :build], unique: true, name: 'package_stemcell_build_idx'
      add_index [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1], unique: true, name: 'package_stemcell_dependency_idx'
      drop_index(nil, :name=>dependency_key_index)
    end

    alter_table(:compiled_packages) do
      drop_column :stemcell_id
    end
  end
end
