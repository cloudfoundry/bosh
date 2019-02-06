Sequel.migration do
  change do
    alter_table(:release_versions) do
      add_column :update_completed, 'boolean', null: false, default: false
    end

    self[:release_versions].update(update_completed: true)
  end
end
