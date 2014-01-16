Sequel.migration do
  change do
    rename_table(:director_attributes, :old_director_attributes)

    create_table(:director_attributes) do
      primary_key :name
      String :name, unique: true, null: false
      String :value
    end

    # Some directors might have created multiple records.
    # Only the first record is ever used after every director restart.
    old_attribute = self[:old_director_attributes].first
    if old_attribute
      self[:director_attributes].insert(name: 'uuid', value: old_attribute[:uuid])
    end

    drop_table(:old_director_attributes)
  end
end
