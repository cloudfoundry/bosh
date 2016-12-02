Sequel.migration do
  change do
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
