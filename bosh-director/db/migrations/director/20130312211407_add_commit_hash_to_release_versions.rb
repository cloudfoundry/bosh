Sequel.migration do
  up do
    alter_table :release_versions do
      add_column :commit_hash, String
      set_column_default :commit_hash, 'unknown'

      add_column :uncommitted_changes, TrueClass
      set_column_default :uncommitted_changes, false
    end
    self[:release_versions].update(commit_hash: 'unknown', uncommitted_changes: false)
  end

  down do
    alter_table :release_versions do
      drop_column :commit_hash
      drop_column :uncommitted_changes
    end
  end
end
