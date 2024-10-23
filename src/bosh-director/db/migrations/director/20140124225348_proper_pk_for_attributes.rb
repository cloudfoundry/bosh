Sequel.migration do
  change do
    if [:sqlite].include?(adapter_scheme)

      rename_table(:director_attributes, :old_director_attributes)

      create_table(:director_attributes) do
        primary_key :id
        String :name, unique: true, null: false
        String :value
      end

      # Some directors might have created multiple records.
      # Only the first record is ever used after every director restart.
      self[:old_director_attributes].each do |old_director_attributes_row|
        self[:director_attributes].insert(old_director_attributes_row)
      end

      drop_table(:old_director_attributes)

    else # mysql + postgresql

      add_column :director_attributes, :temp_name, String, null: true
      self[:director_attributes].update(temp_name: :name)

      alter_table :director_attributes do
        drop_column :name
        rename_column :temp_name, :name
        add_index [:name], unique:true, name: 'unique_attribute_name'
        set_column_not_null :name

        add_primary_key :id
      end

    end
  end
end
