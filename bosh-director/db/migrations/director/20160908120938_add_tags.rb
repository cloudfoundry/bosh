Sequel.migration do
  up do
    create_table :tags do
      primary_key :id
      String :key, :null => false
      String :value, :null => false
      foreign_key :deployment_id, :deployments, :on_delete => :cascade
    end

    alter_table :tags do
      add_index [:key, :value], unique: true, name: 'key_value_idx'
    end
  end

  down do
    drop_table :tags
  end
end

