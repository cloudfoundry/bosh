require 'digest/sha1'

Sequel.migration do
  change do
    affected_constraint = [:package_id, :stemcell_id, :dependency_key]
    constraint = self.indexes(:compiled_packages).find do |_, v|
      v[:columns] == affected_constraint
    end

    if constraint
      if [:mysql2, :mysql].include?(adapter_scheme)
        alter_table(:compiled_packages) do
          drop_index affected_constraint, name: constraint.first
        end
      else
        alter_table(:compiled_packages) do
          drop_constraint constraint.first
        end
      end
    end

    alter_table(:compiled_packages) do
      set_column_type :dependency_key, String, null: false, text: true

      add_column :dependency_key_sha1, String, null: true
    end


    self[:compiled_packages].each do |row|
      self[:compiled_packages].filter(:id => row[:id]).update(
        :dependency_key_sha1 => Digest::SHA1.hexdigest(row[:dependency_key])
      )
    end

    # enforcing dependency_key_sha1 to be not null after adding values to old data
    alter_table(:compiled_packages) do
      set_column_not_null :dependency_key_sha1

      # Dependency key is part of unique constraint since different
      # dependencies uniquely identify compiled package
      add_index [:package_id, :stemcell_id, :dependency_key_sha1], unique: true, name: 'package_stemcell_dependency_key_sha1_idx'
    end

    alter_table(:deployment_properties) do
      set_column_type :value, String, null: false, text: true
    end

    alter_table(:director_attributes) do
      set_column_type :value, String, text: true
    end
  end
end
