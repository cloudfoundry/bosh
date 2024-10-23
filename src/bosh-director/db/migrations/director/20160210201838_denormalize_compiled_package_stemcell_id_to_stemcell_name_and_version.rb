Sequel.migration do
  change do
    if [:sqlite].include?(adapter_scheme)

      rename_table(:compiled_packages, :old_compiled_packages)

      create_table(:compiled_packages) do
        primary_key :id
        String :blobstore_id, null: false
        String :sha1, null: false
        String :dependency_key, null: false
        Integer :build, unsigned: true, null: false
        String :dependency_key_sha1, null: false
        String :stemcell_os
        String :stemcell_version
        foreign_key :package_id, :packages, null: false
        unique [:package_id, :stemcell_os, :stemcell_version, :build]
        unique [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1]
      end

      self[:old_compiled_packages].each do |old_compiled_packages_row|
        if (stemcell_id = old_compiled_packages_row.delete(:stemcell_id))
          stemcell = self[:stemcells].filter(id: stemcell_id).first
          stemcell_os_or_name =
            "#{stemcell[:operating_system]}".empty? ? stemcell[:name] : stemcell[:operating_system]

          old_compiled_packages_row[:stemcell_os] = stemcell_os_or_name
          old_compiled_packages_row[:stemcell_version] =  stemcell[:version]
        end

        self[:compiled_packages].insert(old_compiled_packages_row)
      end

      drop_table(:old_compiled_packages)

    else # mysql + postgresql

      alter_table(:compiled_packages) do
        add_column :stemcell_os, String
        add_column :stemcell_version, String
      end

      self[:compiled_packages].each do |compiled_package|
        next unless compiled_package[:stemcell_id]

        stemcell = self[:stemcells].filter(id: compiled_package[:stemcell_id]).first
        stemcell_os = stemcell[:operating_system].to_s.empty? ? stemcell[:name] : stemcell[:operating_system]

        self[:compiled_packages].filter(id: compiled_package[:id]).update(
          stemcell_os: stemcell_os,
          stemcell_version: stemcell[:version]
        )
      end

      if [:mysql2, :mysql, :postgres].include?(adapter_scheme)
        stemcell_foreign_keys = foreign_key_list(:compiled_packages).select { |constraint| constraint.fetch(:columns).include?(:stemcell_id) }
        raise 'Failed to run migration, found more than 1 stemcell foreign key' if stemcell_foreign_keys.size != 1
        stemcell_foreign_key_name = stemcell_foreign_keys.first.fetch(:name)

        build_indexes = indexes(:compiled_packages).select { |_, value| value.fetch(:columns) == [:package_id, :stemcell_id, :build] }
        if [:mysql2, :mysql].include?(adapter_scheme)
          raise 'Failed to run migration, found more than 1 build index' if build_indexes.size != 1
          # build_indexes is an array, where each element is an array with first element being the name of index
          build_index = build_indexes.first.first
          alter_table(:compiled_packages) do
            drop_index(nil, name: build_index)
          end
        elsif [:postgres].include?(adapter_scheme)
          build_index = build_indexes.empty? ? 'compiled_packages_package_id_stemcell_id_build_key' : build_indexes.first.first
          alter_table(:compiled_packages) do
            drop_constraint(build_index)
          end
        end

        stemcell_indexes = indexes(:compiled_packages).select { |_, value| value.fetch(:columns) == [:package_id, :stemcell_id, :dependency_key_sha1]}
        stemcell_index = stemcell_indexes.empty? ? 'package_stemcell_dependency_key_sha1_idx' : stemcell_indexes.first.first

        alter_table(:compiled_packages) do
          drop_constraint(stemcell_foreign_key_name, :type => :foreign_key)
          add_index [:package_id, :stemcell_os, :stemcell_version, :build], unique: true, name: 'package_stemcell_build_idx'
          add_index [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1], unique: true, name: 'package_stemcell_dependency_idx'
          drop_index(nil, name: stemcell_index)
        end
      end

      alter_table(:compiled_packages) do
        drop_column :stemcell_id
      end

    end
  end
end
